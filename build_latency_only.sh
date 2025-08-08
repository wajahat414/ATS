#!/usr/bin/env bash

set -ex  # Print each command and exit on error

# Detect OS for library path
OS="$(uname)"
if [[ "$OS" == "Darwin" ]]; then
  LIB_PATH_VAR="DYLD_LIBRARY_PATH"
else
  LIB_PATH_VAR="LD_LIBRARY_PATH"
fi

# Create and enter build directory
mkdir -p build_latency
cd build_latency

# Get absolute path to current directory (fallback for macOS without realpath)
get_abs_path() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  else
    # Fallback using Python for macOS
    python3 -c "import os; print(os.path.abspath('$1'))"
  fi
}

ROOT_DIR="$(get_abs_path ..)"

# Set default paths
if [ -z "$1" ]; then
  DDS_HOME="$ROOT_DIR/externel/dds"
  QUICKFIX_HOME="$ROOT_DIR/externel/quickfix"
  LOG4CXX_HOME="$ROOT_DIR/externel/log4cxx"
  INSTALL_PREFIX="$ROOT_DIR/DistributedATS"
else
  INSTALL_PREFIX="$(get_abs_path "$1")"
fi

# Run cmake configuration
cmake ${CMAKE_FLAGS:-} .. -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"

# Build ONLY LatencyTest target (not full install)
cmake --build . --target LatencyTest --config Debug -v

# Install only necessary files for LatencyTest
mkdir -p "$INSTALL_PREFIX/config"
mkdir -p "$INSTALL_PREFIX/spec"
mkdir -p "$INSTALL_PREFIX/bin"

# Copy LatencyTest executable
cp LatencyTest/LatencyTest "$INSTALL_PREFIX/bin/"

# Copy required config files
cp ../config/log4cxx.xml "$INSTALL_PREFIX/config/"
cp ../FIXGateway/spec/FIX44.xml "$INSTALL_PREFIX/spec/"

# Write the environment setup script
cat <<EOM > "$INSTALL_PREFIX/dats_env.sh"
#!/usr/bin/env bash

export DATS_HOME="$INSTALL_PREFIX"
export DDS_HOME="$DDS_HOME"
export QUICKFIX_HOME="$QUICKFIX_HOME"
export LOG4CXX_HOME="$LOG4CXX_HOME"

export $LIB_PATH_VAR="\$DATS_HOME/lib:\$DDS_HOME/lib:\$QUICKFIX_HOME/lib:\$LOG4CXX_HOME/lib:\$$LIB_PATH_VAR"
export LOG4CXX_CONFIGURATION="\$DATS_HOME/config/log4cxx.xml"

EOM

chmod +x "$INSTALL_PREFIX/dats_env.sh"

echo "LatencyTest build complete!"
echo "Executable: $INSTALL_PREFIX/bin/LatencyTest"
echo "To run: source $INSTALL_PREFIX/dats_env.sh && cd LatencyTest && ../bin/LatencyTest -c LatencyTest.cfg"
