#!/bin/bash
# build_cmake.sh

echo "Building test client with CMake (using external/dds)..."

# Make sure we're in the right directory
if [ ! -f "CMakeLists.txt" ]; then
    echo "Error: CMakeLists.txt not found. Run this script from test_client directory."
    exit 1
fi

# Set DDS_HOME to external/dds
export DDS_HOME="$(pwd)/../externel/dds"
echo "Setting DDS_HOME to: $DDS_HOME"

# Verify DDS installation
if [ ! -d "$DDS_HOME/include/fastdds" ]; then
    echo "❌ Error: FastDDS not found at $DDS_HOME"
    echo "Available directories in external/:"
    ls -la ../external/ 2>/dev/null || echo "external/ directory not found"
    exit 1
fi

echo "✅ FastDDS found at: $DDS_HOME"

# Set library paths for runtime
export LD_LIBRARY_PATH="$DDS_HOME/lib:$LD_LIBRARY_PATH"
export DYLD_LIBRARY_PATH="$DDS_HOME/lib:$DYLD_LIBRARY_PATH"

# Check IDL files
if [ ! -f "../GenTools/idl/NewOrderSinglePubSubTypes.cxx" ]; then
    echo "❌ Error: IDL files not found. Please build the main project first:"
    echo "  cd .."
    echo "  ./build_with_cmake.sh"
    exit 1
fi

echo "✅ IDL files found"

# Create build directory
mkdir -p build
cd build

# Clean previous build
rm -rf CMakeCache.txt CMakeFiles/

# Run CMake configuration
echo "Configuring with CMake..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_VERBOSE_MAKEFILE=ON

if [ $? -ne 0 ]; then
    echo "❌ CMake configuration failed!"
    echo "Trying alternative configuration..."
    
    # Try with explicit library paths
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="$DDS_HOME" \
        -DCMAKE_LIBRARY_PATH="$DDS_HOME/lib" \
        -DCMAKE_INCLUDE_PATH="$DDS_HOME/include"
    
    if [ $? -ne 0 ]; then
        echo "❌ Alternative CMake configuration also failed!"
        exit 1
    fi
fi

# Build
echo "Building..."
make VERBOSE=1

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "Executable created: $(pwd)/test_new_order"
    echo "DDS_HOME: $DDS_HOME"
    echo ""
    echo "To run the test:"
    echo "  export DDS_HOME=$DDS_HOME"
    echo "  export DYLD_LIBRARY_PATH=$DDS_HOME/lib:\$DYLD_LIBRARY_PATH"
    echo "  cd build"
    echo "  ./test_new_order"
    echo ""
    echo "Or use the run script:"
    echo "  ./run_test.sh"
else
    echo "❌ Build failed!"
    echo "Check the output above for specific errors."
    exit 1
fi
