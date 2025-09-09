#!/bin/sh
set -euo pipefail
set -x

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

docker build -t dats_deps:latest \
  -f "${REPO_ROOT}/docker/Docker.Build_DATS_Deps" "${REPO_ROOT}"

docker build -t dats_core:latest \
  -f "${REPO_ROOT}/docker/Docker.Build_Distributed_ATS" "${REPO_ROOT}"

docker build --no-cache -t dats_crypto_clob:latest \
  -f "${REPO_ROOT}/docker/Docker.Crypto_CLOB" "${REPO_ROOT}"

echo "Built images:"
docker images | grep -E 'dats_(deps|core|crypto_clob)'
