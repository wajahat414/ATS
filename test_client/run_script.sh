#!/bin/bash
# run_test.sh

echo "Running NewOrderSingle Test..."

# Set up environment
export DDS_HOME="$(pwd)/../external/dds"
export DYLD_LIBRARY_PATH="$DDS_HOME/lib:$DYLD_LIBRARY_PATH"
export LD_LIBRARY_PATH="$DDS_HOME/lib:$LD_LIBRARY_PATH"

echo "DDS_HOME: $DDS_HOME"

# Check if built
if [ ! -f "build/test_new_order" ]; then
    echo "❌ Test executable not found. Build first with:"
    echo "  ./build_cmake.sh"
    exit 1
fi

# Check if MatchingEngine is running
echo "Checking if MatchingEngine is running..."
if pgrep -f "MatchingEngine" > /dev/null; then
    echo "✅ MatchingEngine is running"
else
    echo "⚠️  MatchingEngine not detected. Make sure it's running before sending orders."
    echo "Start MatchingEngine first, then run this test."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Run the test
echo ""
echo "Starting test client..."
cd build
./test_new_order

echo ""
echo "Test completed. Check MatchingEngine logs for results:"
echo "tail -f ../DistributedATS/MiscATS/CryptoCLOB/logs/MatchingEngine.matching_engine_MARKET_BTC.ini.console.log"
