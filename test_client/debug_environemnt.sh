#!/bin/bash
# debug_environment.sh

echo "=== Environment Debug (external/dds) ==="

# Set DDS_HOME to external/dds
export DDS_HOME="$(pwd)/../externel/dds"
echo "DDS_HOME: ${DDS_HOME}"

echo "PATH: ${PATH}"
echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"
echo "DYLD_LIBRARY_PATH: ${DYLD_LIBRARY_PATH}"

echo ""
echo "=== DDS Installation Check ==="
if [ -d "$DDS_HOME" ]; then
    echo "✅ external/dds directory exists"
    ls -la "$DDS_HOME"
else
    echo "❌ external/dds directory not found"
    echo "Available directories:"
    ls -la ../external/ 2>/dev/null || echo "external/ directory not found"
    exit 1
fi

echo ""
echo "=== DDS Headers ==="
if [ -d "$DDS_HOME/include/fastdds" ]; then
    echo "✅ FastDDS headers found"
    ls "$DDS_HOME/include/fastdds/dds/domain/" | head -5
else
    echo "❌ FastDDS headers not found"
    echo "Available includes:"
    ls "$DDS_HOME/include/" 2>/dev/null
fi

echo ""
echo "=== DDS Libraries ==="
if [ -d "$DDS_HOME/lib" ]; then
    echo "Libraries in $DDS_HOME/lib:"
    ls "$DDS_HOME/lib/"*fastdds* 2>/dev/null || echo "No fastdds libraries found"
    ls "$DDS_HOME/lib/"*fastcdr* 2>/dev/null || echo "No fastcdr libraries found"
else
    echo "❌ $DDS_HOME/lib directory not found"
fi

echo ""
echo "=== IDL Files ==="
ls -la ../GenTools/idl/NewOrder* 2>/dev/null || echo "❌ NewOrder IDL files not found"
ls -la ../GenTools/idl/Header* 2>/dev/null || echo "❌ Header IDL files not found"

echo ""
echo "=== Build Test ==="
echo '#include <fastdds/dds/domain/DomainParticipantFactory.hpp>' > test.cpp
echo 'int main() { return 0; }' >> test.cpp

g++ -I${DDS_HOME}/include -L${DDS_HOME}/lib test.cpp -lfastdds -lfastcdr -o test 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Basic compilation works"
    rm test test.cpp
else
    echo "❌ Basic compilation failed"
    echo "Trying alternative library names..."
    g++ -I${DDS_HOME}/include -L${DDS_HOME}/lib test.cpp -lfastrtps -lfastcdr -o test 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Compilation works with fastrtps library name"
        rm test test.cpp
    else
        echo "❌ Compilation failed with both library names"
    fi
    rm test.cpp
fi
