#!/usr/bin/env bash
# fast_build.sh - Build only specific components

set -e

# Parse arguments
COMPONENT=""
CLEAN_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --component|-c)
            COMPONENT="$2"
            shift 2
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        *)
            echo "Usage: $0 --component <component> [--clean]"
            echo "Components: LatencyTest, MatchingEngine, FIXGateway, DataService"
            exit 1
            ;;
    esac
done

# Set up environment (reuse existing if available)
if [ -f "DistributedATS/dats_env.sh" ]; then
    source DistributedATS/dats_env.sh
fi

cd build

# Build only the specific component
case $COMPONENT in
    LatencyTest)
        if [ "$CLEAN_BUILD" = true ]; then
            rm -rf LatencyTest/
        fi
        make LatencyTest -j4
        cp LatencyTest/LatencyTest ../DistributedATS/bin/
        ;;
    MatchingEngine)
        if [ "$CLEAN_BUILD" = true ]; then
            rm -rf MatchingEngine/
        fi
        make MatchingEngine -j4
        cp MatchingEngine/src/MatchingEngine ../DistributedATS/bin/
        ;;
    FIXGateway)
        if [ "$CLEAN_BUILD" = true ]; then
            rm -rf FIXGateway/
        fi
        make FIXGateway -j4
        cp FIXGateway/src/FIXGateway ../DistributedATS/bin/
        ;;
    DataService)
        if [ "$CLEAN_BUILD" = true ]; then
            rm -rf DataService/
        fi
        make DataService -j4
        cp DataService/src/DataService ../DistributedATS/bin/
        ;;
    *)
        echo "Unknown component: $COMPONENT"
        exit 1
        ;;
esac

echo "✅ $COMPONENT built successfully!"
