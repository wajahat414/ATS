#!/usr/bin/env bash
cd  ../DistributedATS

# Navigate to the DistributedATS root directory
# load python virtual environment
source venv/bin/activate
# load environment variables
pip install psutil
source dats_env.sh

export BASEDIR_ATS=/Users/wajahat/Documents/WorkSpace/ForexSystem/RefernceCodes/DistributedATS/DistributedATS/MiscATS/CryptoCLOB
# change directory to MiscATS
cd MiscATS

# Run  start_ats.py script with path to crypto_ats.json
python3 start_ats.py --ats CryptoCLOB/crypto_ats.json

