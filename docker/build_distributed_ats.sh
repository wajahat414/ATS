#!/bin/bash

set -euo pipefail

cd /opt/distributed_ats_src

cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr/local -DDDS_ROOT_DIR=/usr/local -DLOG4CXX_ROOT_DIR=/usr/local -DQUICKFIX_ROOT_DIR=/usr/local -DLIQUIBOOK_ROOT_DIR=/usr/local
cmake --build build --verbose --target install -j2
