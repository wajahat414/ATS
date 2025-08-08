#!/usr/bin/env bash

export DATS_HOME="/Users/wajahat/Documents/WorkSpace/ForexSystem/RefernceCodes/DistributedATS/DistributedATS"
export DDS_HOME="/Users/wajahat/Documents/WorkSpace/ForexSystem/RefernceCodes/DistributedATS/externel/dds"
export QUICKFIX_HOME="/Users/wajahat/Documents/WorkSpace/ForexSystem/RefernceCodes/DistributedATS/externel/quickfix"
export LOG4CXX_HOME="/Users/wajahat/Documents/WorkSpace/ForexSystem/RefernceCodes/DistributedATS/externel/log4cxx"

export DYLD_LIBRARY_PATH="$DATS_HOME/lib:$DDS_HOME/lib:$QUICKFIX_HOME/lib:$LOG4CXX_HOME/lib:$DYLD_LIBRARY_PATH"
export LOG4CXX_CONFIGURATION="$DATS_HOME/config/log4cxx.xml"

