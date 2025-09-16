#!/usr/bin/env bash
set -e 

cd "$(dirname "$0")/../DistributedATS"


# Navigate to the DistributedATS root directory
# load python virtual environment
VENV_DIR="$(pwd)/venv"
if [ ! -f "$VENV_DIR/bin/activate" ]; then
    python3 -m venv "$VENV_DIR"
fi
# Install dependency (move to requirements.txt for better practice)
source "$VENV_DIR/bin/activate"
VENV_PYTHON="$VENV_DIR/bin/python"


"$VENV_PYTHON" -m pip install -q --upgrade pip
"$VENV_PYTHON" -m pip install -q psutil

# Load environment variables for ATS from the current directory (inner DistributedATS)
if [ -f "dats_env.sh" ]; then
    # shellcheck disable=SC1091
    source dats_env.sh
else
    echo "Error: dats_env.sh not found under $(pwd)."
    exit 1
fi

export BASEDIR_ATS="$(pwd)/MiscATS/CryptoCLOB"

# change directory to MiscATS
cd MiscATS

# Clean logs (confirm path)
if [ -d "CryptoCLOB/logs" ]; then
    rm -rf CryptoCLOB/logs
fi

# Run  start_ats.py script with path to crypto_ats.json
"$VENV_PYTHON" start_ats.py --ats CryptoCLOB/crypto_ats.json
