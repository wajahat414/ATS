package components

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/quickfixgo/enum"
	"github.com/quickfixgo/field"
	fix44nos "github.com/quickfixgo/fix44/newordersingle"
	"github.com/quickfixgo/quickfix"
	"github.com/segmentio/kafka-go"
	"github.com/shopspring/decimal"
)

type KafkaMetrics struct {
	new_orders_count          int64 // atomic
	execution_report_count    int64 // atomic
	time_for_new_order        time.Duration
	time_for_execution_report time.Duration
	exec_report_start_time    time.Time
	exec_report_end_time      time.Time
	new_order_start_time      time.Time
	new_order_end_time        time.Time

	execReportStartOnce sync.Once
	newOrderStartOnce   sync.Once
}

// KafkaService consumes new orders from Kafka and publishes execution reports to Kafka.
type KafkaService struct {
	fixClient   *FIXTradeClient
	investors   *map[string]InvestorCredentials
	orderReader *kafka.Reader
	execWriter  *kafka.Writer
	// Fallback direct readers (no group) per-partition
	directReaders []*kafka.Reader
	usingDirect   bool
	execQueue     chan kafka.Message
	metrics       KafkaMetrics
}

type KafkaConfig struct {
	Brokers          []string
	OrdersTopic      string
	ExecReportsTopic string
	GroupID          string
}

func NewKafkaService(cfg KafkaConfig, fixClient *FIXTradeClient, investors *map[string]InvestorCredentials) *KafkaService {
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:  cfg.Brokers,
		GroupID:  cfg.GroupID,
		Topic:    cfg.OrdersTopic,
		MinBytes: 1,    // 1B
		MaxBytes: 10e6, // 10MB
		MaxWait:  250 * time.Millisecond,
		// Tune group settings to be more responsive in single-broker dev
		SessionTimeout:        30 * time.Second,
		HeartbeatInterval:     3 * time.Second,
		RebalanceTimeout:      30 * time.Second,
		WatchPartitionChanges: true,
		Logger:                appLoggerProxy{},
		ErrorLogger:           appLoggerProxy{},
	})

	writer := &kafka.Writer{
		Addr:         kafka.TCP(cfg.Brokers...),
		Topic:        cfg.ExecReportsTopic,
		RequiredAcks: kafka.RequireAll,
		Balancer:     &kafka.Hash{},
		BatchTimeout: 10 * time.Millisecond,
		// Help in dev: auto-create exec topic if not present
		AllowAutoTopicCreation: true,
	}

	svc := &KafkaService{
		fixClient:   fixClient,
		investors:   investors,
		orderReader: reader,
		execWriter:  writer,
		execQueue:   make(chan kafka.Message, 8192),
		metrics:     KafkaMetrics{},
	}

	// Wire FIX execution report -> Kafka publisher
	fixClient.SetExecutionReportHandler(func(er ExecutionReport) {
		// Log the struct before serialization for debugging transparency.

		c := atomic.AddInt64(&svc.metrics.execution_report_count, 1)

		svc.metrics.execReportStartOnce.Do(func() {
			svc.metrics.exec_report_start_time = time.Now()
		})

		if c == 20000 {

			svc.metrics.exec_report_end_time = time.Now()
			d := time.Since(svc.metrics.exec_report_start_time)
			svc.metrics.time_for_execution_report = d

			rps := float64(c) / d.Seconds()
			AppLog.Printf("Metrics execution reports=%d total=%s (%.1f msg/s)", c, d, rps)

		}
		if c == 40000 {

			svc.metrics.exec_report_end_time = time.Now()
			d := time.Since(svc.metrics.exec_report_start_time)
			svc.metrics.time_for_execution_report = d

			rps := float64(c) / d.Seconds()
			AppLog.Printf("Metrics execution reports=%d total=%s (%.1f msg/s)", c, d, rps)

		}

		AppLog.Printf("kafka: exec report count %v struct before serialize: %+v", svc.metrics.execution_report_count, er)
		b, err := json.Marshal(er)
		if err != nil {
			AppLog.Printf("kafka: marshal exec report error: %v", err)
			return
		}
		msg := kafka.Message{Key: []byte(er.OrderId), Value: b}
		// Write in a background goroutine to avoid blocking FIX path

		select {
		case svc.execQueue <- msg:
		default:
			timer := time.NewTimer(500 * time.Millisecond)
			defer timer.Stop()
			select {
			case svc.execQueue <- msg:
			case <-timer.C:
				svc.execQueue <- msg

			}
		}

	})

	return svc
}

// Start begins consuming order messages and sending FIX orders.
func (s *KafkaService) Start(ctx context.Context) error {
	AppLog.Printf("kafka: starting consumer brokers=%v group=%s topic=%s", s.orderReader.Config().Brokers, s.orderReader.Config().GroupID, s.orderReader.Config().Topic)
	// Probe topic metadata to ensure connectivity and partitions

	s.startExecPublisher(ctx)
	go func() {
		b := s.orderReader.Config().Brokers
		if len(b) == 0 {
			AppLog.Printf("kafka: no brokers configured")
			return
		}
		dctx, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		conn, err := kafka.DialContext(dctx, "tcp", b[0])
		if err != nil {
			AppLog.Printf("kafka: metadata dial failed broker=%s err=%v", b[0], err)
			return
		}
		defer conn.Close()
		parts, err := conn.ReadPartitions(s.orderReader.Config().Topic)
		if err != nil {
			AppLog.Printf("kafka: metadata read partitions failed: %v", err)
			return
		}
		AppLog.Printf("kafka: topic %s partitions: %d", s.orderReader.Config().Topic, len(parts))
		for _, p := range parts {
			if p.Topic == s.orderReader.Config().Topic {
				AppLog.Printf("kafka: partition id=%d leader=%s:%d replicas=%v isr=%v", p.ID, p.Leader.Host, p.Leader.Port, p.Replicas, p.Isr)
			}
		}
	}()
	// Periodic stats to confirm assignments, lags, and activity
	go func() {
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				st := s.orderReader.Stats()
				AppLog.Printf("kafka: consumer stats: %+v", st)
				// After initial period, if still not assigned (partition "-1"), fallback
				if !s.usingDirect && st.Partition == "-1" && st.Messages == 0 {
					AppLog.Printf("kafka: no group assignment yet (partition=-1). Falling back to direct partition readers from latest.")
					if err := s.startDirectReaders(ctx); err != nil {
						AppLog.Printf("kafka: fallback to direct readers failed: %v", err)
					} else {
						// Close group reader; direct readers will take over
						_ = s.orderReader.Close()
						s.usingDirect = true
						return
					}
				}
			}
		}
	}()
	go func() {
		for {
			m, err := s.orderReader.ReadMessage(ctx)
			if err != nil {
				if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) || errors.Is(err, io.EOF) {
					// benign during shutdown or idle / rebalance
					if errors.Is(err, io.EOF) {
						// AppLog.Printf("kafka: read EOF (rebalance or idle)")
					}
					time.Sleep(200 * time.Millisecond)
					continue
				}
				if ctx.Err() != nil {
					return
				}
				AppLog.Printf("kafka: read error: %v", err)
				time.Sleep(1 * time.Second)
				continue
			}
			AppLog.Printf("kafka: received message partition=%d offset=%d key=%q bytes=%d headers=%s", m.Partition, m.Offset, string(m.Key), len(m.Value), headersToString(m.Headers))
			// Print the raw message (truncated) before attempting to deserialize.
			AppLog.Printf("kafka: raw new order message preview: %s", previewString(m.Value, 2048))

			var req InvestorOrderRequest
			dec := json.NewDecoder(bytes.NewReader(m.Value))
			dec.DisallowUnknownFields() // catch silent field mismatches
			if err := dec.Decode(&req); err != nil {
				AppLog.Printf("kafka: bad order json: %v value=%s", err, string(m.Value))
				continue
			}
			AppLog.Printf("kafka: processing order token=%s sym=%s exch=%s qty=%d px=%d side=%s", req.UserToken, req.Instrument.Symbol, req.Instrument.SecurityExchange, req.NewOrderSingle.OrderQty, req.NewOrderSingle.Price, req.NewOrderSingle.Side)
			if err := s.handleNewOrder(req); err != nil {
				AppLog.Printf("kafka: handle order error: %v", err)
			}
		}
	}()
	return nil
}

func (s *KafkaService) Close(ctx context.Context) error {
	var errs []string
	if err := s.orderReader.Close(); err != nil {
		errs = append(errs, fmt.Sprintf("reader: %v", err))
	}
	for _, r := range s.directReaders {
		if r != nil {
			if err := r.Close(); err != nil {
				errs = append(errs, fmt.Sprintf("direct-reader: %v", err))
			}
		}
	}
	if err := s.execWriter.Close(); err != nil {
		errs = append(errs, fmt.Sprintf("writer: %v", err))
	}
	if len(errs) > 0 {
		return errors.New(strings.Join(errs, "; "))
	}
	return nil
}

func (s *KafkaService) handleNewOrder(in InvestorOrderRequest) error {
	// Lookup investor credentials using provided token
	// creds, ok := (*s.investors)[in.UserToken]
	// if !ok {
	// 	return fmt.Errorf("unknown user token len=%d prefix=%q", len(in.UserToken), previewString([]byte(in.UserToken), 16))
	// }

	// Build a unique client order id
	clOrdID := in.OrigClientOrderID

	clordid := field.NewClOrdID(in.OrigClientOrderID)
	side := field.NewSide(enum.Side(in.NewOrderSingle.Side))
	transacttime := field.NewTransactTime(time.Now())
	ordtype := field.NewOrdType(enum.OrdType(in.NewOrderSingle.OrdType))

	newOrder := fix44nos.New(clordid, side, transacttime, ordtype)
	newOrder.Body.Set(field.NewSymbol(in.Instrument.Symbol))
	newOrder.Body.Set(field.NewSecurityExchange(in.Instrument.SecurityExchange))
	newOrder.Body.Set(field.NewPrice(decimal.NewFromInt32(in.NewOrderSingle.Price), 0))
	newOrder.Body.Set(field.NewOrderQty(decimal.NewFromInt32(in.NewOrderSingle.OrderQty), 0))
	newOrder.Body.Set(field.NewTimeInForce(enum.TimeInForce(in.NewOrderSingle.TimeInForce)))

	AppLog.Printf("kafka: sending FIX order clOrdID=%s sym=%s exch=%s", clOrdID, in.Instrument.Symbol, in.Instrument.SecurityExchange)

	// Send using existing FIX session
	var sess quickfix.SessionID = s.fixClient.serviceSessionID
	if err := quickfix.SendToTarget(newOrder, sess); err != nil {
		return fmt.Errorf("send to target: %w", err)
	}

	// Track the order for later status lookups (mirrors REST path behavior)
	s.fixClient.insertInvestorOrderMap(in.UserToken, clOrdID)
	return nil
}

// headersToString formats Kafka headers for logging.
func headersToString(h []kafka.Header) string {
	if len(h) == 0 {
		return "-"
	}
	parts := make([]string, 0, len(h))
	for _, hd := range h {
		parts = append(parts, fmt.Sprintf("%s[%dB]", hd.Key, len(hd.Value)))
	}
	return strings.Join(parts, ",")
}

// previewString returns a safe truncated preview of a byte slice for logs.
func previewString(b []byte, max int) string {
	if max <= 0 {
		max = 256
	}
	s := string(b)
	if len(s) > max {
		return s[:max] + "...(truncated)"
	}
	return s
}

// appLoggerProxy forwards kafka-go logs to AppLog
type appLoggerProxy struct{}

func (appLoggerProxy) Printf(format string, v ...interface{}) {
	AppLog.Printf("kafka-go: "+format, v...)
}

// startDirectReaders discovers partitions and starts a reader per partition from the latest offset.
func (s *KafkaService) startDirectReaders(ctx context.Context) error {
	b := s.orderReader.Config().Brokers
	if len(b) == 0 {
		return fmt.Errorf("no brokers configured")
	}
	topic := s.orderReader.Config().Topic
	dctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	conn, err := kafka.DialContext(dctx, "tcp", b[0])
	if err != nil {
		return fmt.Errorf("dial broker: %w", err)
	}
	defer conn.Close()
	parts, err := conn.ReadPartitions(topic)
	if err != nil {
		return fmt.Errorf("read partitions: %w", err)
	}
	if len(parts) == 0 {
		return fmt.Errorf("topic %s has no partitions", topic)
	}
	AppLog.Printf("kafka: starting direct readers for topic=%s partitions=%d", topic, len(parts))
	readers := make([]*kafka.Reader, 0, len(parts))
	for _, p := range parts {
		if p.Topic != topic {
			continue
		}
		rc := kafka.ReaderConfig{
			Brokers:     b,
			Topic:       topic,
			Partition:   p.ID,
			MinBytes:    1,
			MaxBytes:    10e6,
			StartOffset: kafka.LastOffset,
			Logger:      appLoggerProxy{},
			ErrorLogger: appLoggerProxy{},
		}
		r := kafka.NewReader(rc)
		readers = append(readers, r)
		// Launch a goroutine per partition
		go func(rp *kafka.Reader, pid int) {
			AppLog.Printf("kafka: direct reader started partition=%d from=latest", pid)
			for {
				m, err := rp.ReadMessage(ctx)
				if err != nil {
					if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) || errors.Is(err, io.EOF) {
						time.Sleep(200 * time.Millisecond)
						continue
					}
					if ctx.Err() != nil {
						return
					}
					AppLog.Printf("kafka: direct read error p=%d: %v", pid, err)
					time.Sleep(1 * time.Second)
					continue
				}
				AppLog.Printf("kafka: direct received p=%d offset=%d key=%q bytes=%d headers=%s", pid, m.Offset, string(m.Key), len(m.Value), headersToString(m.Headers))
				AppLog.Printf("kafka: raw new order message preview: %s", previewString(m.Value, 2048))
				var req InvestorOrderRequest
				dec := json.NewDecoder(bytes.NewReader(m.Value))
				dec.DisallowUnknownFields()
				if err := dec.Decode(&req); err != nil {
					AppLog.Printf("kafka: bad order json: %v value=%s", err, string(m.Value))
					continue
				}
				AppLog.Printf("kafka: processing order token=%s sym=%s exch=%s qty=%d px=%d side=%s", req.UserToken, req.Instrument.Symbol, req.Instrument.SecurityExchange, req.NewOrderSingle.OrderQty, req.NewOrderSingle.Price, req.NewOrderSingle.Side)
				// metrics for new orders
				s.metrics.newOrderStartOnce.Do(func() {
					s.metrics.new_order_start_time = time.Now()
				})
				cnt := atomic.AddInt64(&s.metrics.new_orders_count, 1)
				if cnt == 20000 {
					s.metrics.new_order_end_time = time.Now()
					d := time.Since(s.metrics.new_order_start_time)
					s.metrics.time_for_new_order = d
					rps := float64(cnt) / d.Seconds()
					AppLog.Printf("Metrics new orders=%d total=%s (%.1f msg/s)", cnt, d, rps)
				}
				if err := s.handleNewOrder(req); err != nil {
					AppLog.Printf("kafka: handle order error: %v", err)
				}
				time.Sleep(10 * time.Millisecond)
			}
		}(r, p.ID)
	}
	s.directReaders = readers
	return nil
}

func (s *KafkaService) startExecPublisher(ctx context.Context) {

	go func() {
		batch := make([]kafka.Message, 0, 1024)
		flush := func() {
			if len(batch) == 0 {
				return
			}
			if err := s.execWriter.WriteMessages(ctx, batch...); err != nil {
				AppLog.Printf("kafka: publish exec batch error (n=%d): %v", len(batch), err)
				// simple retry with small backoff
				time.Sleep(50 * time.Millisecond)
				if err2 := s.execWriter.WriteMessages(ctx, batch...); err2 != nil {
					AppLog.Printf("kafka: publish exec batch retry failed: %v", err2)
				}

			} else {
				AppLog.Printf("kafka: published exec batch n=%d topic=%s", len(batch), s.execWriter.Topic)

			}
			batch = batch[:0]

		}
		ticker := time.NewTicker(10 * time.Millisecond)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				flush()
				return
			case msg := <-s.execQueue:
				batch = append(batch, msg)
			drain:
				for len(batch) < cap(batch) {
					select {
					case m := <-s.execQueue:
						batch = append(batch, m)
					default:
						break drain
					}
				}
				if len(batch) >= 1000 {
					flush()
				}
			case <-ticker.C:
				flush()

			}
		}

	}()

}
