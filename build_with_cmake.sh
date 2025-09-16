#!/usr/bin/env bash

set -ex  # Print each command and exit on error

# Detect OS for library path
OS="$(uname)"
if [[ "$OS" == "Darwin" ]]; then
  LIB_PATH_VAR="DYLD_LIBRARY_PATH"
  CMAKE_FLAGS="-G Ninja"
else
  LIB_PATH_VAR="LD_LIBRARY_PATH"
fi

# Create and enter build directory
mkdir -p build
cd build

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

if [ ! -d "$DDS_HOME/include/fastdds" ]; then
    echo "Error: DDS headers not found at $DDS_HOME/include/fastdds. Please build/install DDS first."
    exit 1
fi

# Run cmake and build


cmake ${CMAKE_FLAGS:-} .. \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
  -DCMAKE_BUILD_TYPE=Debug  \
  -DDDS_ROOT_DIR="$DDS_HOME" \
  -DQUICKFIX_ROOT_DIR="$QUICKFIX_HOME" \
  -DLOG4CXX_ROOT_DIR="$LOG4CXX_HOME" \
  -DLIQUIBOOK_ROOT="$LIQUIBOOK_HOME" 

cmake ${CMAKE_FLAGS:-} .. -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"

ninja -v install

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

