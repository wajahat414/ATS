package components

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/segmentio/kafka-go"
)

// TestKafkaConnectivity starts a consumer first (latest), then produces a message,
// and verifies the message is received.
// Skips if KAFKA_BROKERS env is empty.
func TestKafkaConnectivity(t *testing.T) {
	brokersEnv := os.Getenv("KAFKA_BROKERS")
	if brokersEnv == "" {
		t.Skip("KAFKA_BROKERS not set; skipping integration test")
		return
	}
	brokers := strings.Split(brokersEnv, ",")

	// Topic: use TEST_KAFKA_TOPIC if set, otherwise a random throwaway
	var b [8]byte
	_, _ = rand.Read(b[:])
	topic := os.Getenv("TEST_KAFKA_TOPIC")
	if topic == "" {
		topic = "test-conn-" + hex.EncodeToString(b[:])
	}
	payload := []byte("hello-kafka-" + hex.EncodeToString(b[:]))
	t.Logf("Kafka test using brokers=%v topic=%s", brokers, topic)

	// writer: attempt to auto-create topic via produce, with retries
	w := &kafka.Writer{
		Addr:                   kafka.TCP(brokers...),
		Topic:                  topic,
		AllowAutoTopicCreation: true,
		RequiredAcks:           kafka.RequireOne,
	}
	defer w.Close()

	var writeErr error
	for i := 0; i < 10; i++ {
		ctxW, cancelW := context.WithTimeout(context.Background(), 3*time.Second)
		writeErr = w.WriteMessages(ctxW, kafka.Message{Value: payload})
		cancelW()
		if writeErr == nil {
			break
		}
		// UnknownTopicOrPartition often resolves after auto-create; wait and retry
		time.Sleep(500 * time.Millisecond)
	}
	if writeErr != nil {
		t.Fatalf("write failed after retries: %v", writeErr)
	}
	t.Logf("Kafka test wrote message bytes=%d to topic=%s", len(payload), topic)

	// reader: no group. We'll scan from the beginning and stop when our payload is seen or timeout.
	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers:     brokers,
		Topic:       topic,
		StartOffset: kafka.FirstOffset,
		MinBytes:    1,
		MaxBytes:    10e6,
	})
	defer r.Close()

	deadline := time.Now().Add(10 * time.Second)
	for {
		if time.Now().After(deadline) {
			t.Fatalf("timeout waiting for message on topic=%s", topic)
		}
		ctxR, cancelR := context.WithTimeout(context.Background(), 2*time.Second)
		msg, err := r.ReadMessage(ctxR)
		cancelR()
		if err != nil {
			continue
		}
		if string(msg.Value) == string(payload) {
			t.Logf("Kafka test received message partition=%d offset=%d", msg.Partition, msg.Offset)
			break
		}
	}
}
