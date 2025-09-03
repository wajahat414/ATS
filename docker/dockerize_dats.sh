#!/bin/sh

set -x 

# Core
docker build -t ghcr.io/wajahat/distributed_ats_deps:latest -f Docker.Build_DATS_Deps .
docker build -t ghcr.io/wajahat/distributed_ats:latest -f Docker.Build_Distributed_ATS .
docker build --no-cache -t ghcr.io/wajahat/dats_crypto_clob:latest -f Docker.Crypto_CLOB .

# docker push ghcr.io/wajahat/distributed_ats_deps:latest
# docker push ghcr.io/wajahat/distributed_ats:latest
# docker push ghcr.io/wajahat/dats_crypto_clob:latest
