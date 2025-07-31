#!/usr/bin/env bash

# Default settings
SHOW_CONSOLE=true
CONFIG_FILE="LatencyTest.cfg"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --silent|-s)
            SHOW_CONSOLE=false
            shift
            ;;
        --config|-c)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --silent, -s     Run without console output (log only)"
            echo "  --config, -c     Specify config file (default: LatencyTest.cfg)"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set up environment
cd ../DistributedATS
source dats_env.sh

# Navigate to the LatencyTest directory
cd ..
cd LatencyTest

# Create logs directory
mkdir -p logs

# Get timestamp for unique log file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="logs/latency_test_${TIMESTAMP}.log"

echo "Starting LatencyTest with logging..."
echo "Config file: $CONFIG_FILE"
echo "Log file: $LOG_FILE"

if [ "$SHOW_CONSOLE" = true ]; then
    echo "Console output: ENABLED (use --silent to disable)"
    echo "Watch logs: tail -f $LOG_FILE"
else
    echo "Console output: DISABLED (logging to file only)"
fi
echo ""

# Set up environment for logging
export DATS_LOG_HOME=./logs

# Log session start with system info
{
    echo "$(date): LatencyTest session started"
    echo "$(date): Using config: $CONFIG_FILE"
    echo "$(date): Environment - DATS_LOG_HOME=$DATS_LOG_HOME"
    echo "$(date): System: $(uname -a)"
    echo "$(date): Working directory: $(pwd)"
    echo "----------------------------------------"
} >> "$LOG_FILE"

# Run LatencyTest based on console output preference
if [ "$SHOW_CONSOLE" = true ]; then
    # Show on console AND log to file
    ../build/LatencyTest/LatencyTest -c "$CONFIG_FILE" 2>&1 | tee -a "$LOG_FILE"
else
    # Log to file only (silent mode)
    ../build/LatencyTest/LatencyTest -c "$CONFIG_FILE" >> "$LOG_FILE" 2>&1
fi

# Capture exit code
EXIT_CODE=$?

# Log session end
{
    echo "----------------------------------------"
    echo "$(date): LatencyTest session completed with exit code: $EXIT_CODE"
} >> "$LOG_FILE"

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ LatencyTest completed successfully"
else
    echo "❌ LatencyTest failed with exit code: $EXIT_CODE"
fi
echo "📄 Log saved to: $LOG_FILE"

# Show log file size and quick stats
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(wc -c < "$LOG_FILE")
    echo "📊 Log file size: $LOG_SIZE bytes"
    
    # Show quick latency stats if available
    if grep -q "Round trip latency" "$LOG_FILE"; then
        echo "📈 Quick latency summary:"
        grep "Round trip latency" "$LOG_FILE" | tail -5
    fi
fi

exit $EXIT_CODE
