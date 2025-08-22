/*
   Copyright (C) 2024 Mike Kipnis - DistributedATS
*/

package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/quickfixgo/quickfix"

	_ "github.com/mattn/go-sqlite3"

	components "golang_rest_service/components"

	"github.com/joho/godotenv"
	flag "github.com/spf13/pflag"
)

func main() {
	// Load .env if present (does not error if missing)
	_ = godotenv.Load()

	var cfgFileName string

	var rest_port_number *int = flag.Int("rest_port_number", 28100, "REST Service Port Number")
	var quickfix_config *string = flag.String("quickfix_config", "config/tradeclient.cfg", "QuickFIX Config")
	var investors_db *string = flag.String("investor_db", "investors/investors.db", "Investors DB")

	// Service mode flags
	var rest_enable *bool = flag.Bool("rest_enable", getEnvBool("REST_ENABLE", true), "Enable REST API service")
	var kafka_enable *bool = flag.Bool("kafka_enable", getEnvBool("KAFKA_ENABLE", false), "Enable Kafka service for orders and exec reports")
	// Kafka config flags
	var kafka_brokers *string = flag.String("kafka_brokers", getEnv("KAFKA_BROKERS", "localhost:9092"), "Comma-separated Kafka brokers")
	var kafka_orders_topic *string = flag.String("kafka_orders_topic", getEnv("KAFKA_ORDERS_TOPIC", "new_orders"), "Kafka topic to consume new orders")
	var kafka_exec_topic *string = flag.String("kafka_exec_topic", getEnv("KAFKA_EXEC_TOPIC", "execution_report"), "Kafka topic to publish execution reports")
	var kafka_group_id *string = flag.String("kafka_group_id", getEnv("KAFKA_GROUP_ID", "golang-fix-service"), "Kafka consumer group id")

	flag.Parse()
	logDir := "logs"
	_ = os.MkdirAll(logDir, 0o755)
	logFilePath := filepath.Join(logDir, "gin.log")
	logFile, err := os.OpenFile(logFilePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)

	if err != nil {
		fmt.Printf("unable to open gin log file: %v\n", err)
		os.Exit(1)
	}
	defer logFile.Close()
	gin.DisableConsoleColor()
	gin.DefaultWriter = io.MultiWriter(logFile, os.Stdout) // info logs
	gin.DefaultErrorWriter = gin.DefaultWriter

	components.InitLogger(gin.DefaultWriter)

	var investors = components.PopulateInvestorCredenital(*investors_db)

	cfg, err := os.Open(*quickfix_config)
	if err != nil {
		fmt.Printf("error opening %v, %v", cfgFileName, err)
		os.Exit(0)
	}
	defer cfg.Close()

	stringData, readErr := io.ReadAll(cfg)
	if readErr != nil {
		fmt.Printf("error reading cfg: %s,", readErr)
	}

	fmt.Printf("String Data: %s", stringData)
	appSettings, err := quickfix.ParseSettings(bytes.NewReader(stringData))
	if err != nil {
		fmt.Printf("error reading cfg: %s,", err)
	}

	fixTradeClient := components.NewFIXTradeClient("TEST")
	fileLogFactory, err := quickfix.NewFileLogFactory(appSettings)

	if err != nil {
		fmt.Printf("error creating file log factory: %s,", err)
	}

	initiator, err := quickfix.NewInitiator(fixTradeClient, quickfix.NewMemoryStoreFactory(), appSettings, fileLogFactory)
	if err != nil {
		fmt.Printf("unable to create initiator: %s", err)
	}

	err = initiator.Start()
	if err != nil {
		fmt.Printf("unable to start initiator: %s", err)
	}

	// Optionally start Kafka service
	if *kafka_enable {
		cfg := components.KafkaConfig{
			Brokers:          strings.Split(*kafka_brokers, ","),
			OrdersTopic:      *kafka_orders_topic,
			ExecReportsTopic: *kafka_exec_topic,
			GroupID:          *kafka_group_id,
		}
		kafkaSvc := components.NewKafkaService(cfg, fixTradeClient, &investors)
		if err := kafkaSvc.Start(context.Background()); err != nil {
			fmt.Fprintf(gin.DefaultWriter, "failed to start Kafka service: %v\n", err)
		}
	}

	// Optionally start REST service
	if *rest_enable {
		rest_service := gin.Default()

		components.InstrumentService(rest_service, fixTradeClient)
		components.MarketDataService(rest_service, fixTradeClient)
		components.SubmitOrderService(rest_service, fixTradeClient, &investors)
		components.CancelOrderService(rest_service, fixTradeClient, &investors)
		components.InvestorOrdersService(rest_service, fixTradeClient, &investors)
		components.InvestorOrderStatusService(rest_service, fixTradeClient, &investors)

		rest_run_port := fmt.Sprintf(":%d", *rest_port_number)
		rest_service.Run(rest_run_port)
	} else {
		// If REST is disabled, keep process alive
		select {}
	}

}

// helpers to read env with defaults
func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func getEnvInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		var out int
		_, err := fmt.Sscanf(v, "%d", &out)
		if err == nil {
			return out
		}
	}
	return def
}

func getEnvBool(key string, def bool) bool {
	if v := os.Getenv(key); v != "" {
		switch strings.ToLower(v) {
		case "1", "true", "yes", "y":
			return true
		case "0", "false", "no", "n":
			return false
		}
	}
	return def
}
