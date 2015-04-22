#! /bin/bash

# Directory variables
# NOTE: if using mac, need to install coreutils / greadlink, or hardcode here...
DIRNAME=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
REAL_DIRNAME=`readlink -f ${DIRNAME}` || REAL_DIRNAME=`greadlink -f ${DIRNAME}`
export APP_HOME=$REAL_DIRNAME
export GDD_HOME=$APP_HOME


# TODO: set location of DeepDive local install!
export DEEPDIVE_HOME=`cd ${REAL_DIRNAME}/../..; pwd`


# TODO: change these variables for db connection, etc.
# TODO(alex): merge db/pg vars...
export HOSTNAME=raiders4

export PGHOST=${HOSTNAME}.stanford.edu
export DBHOST=$PGHOST
export GPHOST=$PGHOST

export PGPORT=6432
export DBPORT=$PGPORT
export GPPORT=8082

export DDUSER=senwu
export PGUSER=$DDUSER
export DBUSER=$PGUSER

export PGPASSWORD=${PGPASSWORD:-}

export DBNAME=genomics_large
export DBNAME=genomics

export GPPATH=/lfs/${HOSTNAME}/0/${DDUSER}/develop/grounding
#export GPPATH=/lfs/${HOSTNAME}/0/$DDUSER/greenplum_gpfdist 

export LFS_DIR=/lfs/$HOSTNAME/0/$DDUSER


# TODO: Machine Configuration
export MEMORY="256g"
# export MEMORY="16g"

export PARALLELISM=80

export SBT_OPTS="-Xmx$MEMORY"
export JAVA_OPTS="-Xmx$MEMORY"

# Using ddlib, analysis util lib
PYTHONPATH=$DEEPDIVE_HOME/ddlib:$REAL_DIRNAME/analysis/util:$PYTHONPATH


# Other:
# The number of sentences in the sentences table
export SENTENCES=95022507
# The input batch size for extractors working on the sentences table
export SENTENCES_BATCH_SIZE=`echo  "(" ${SENTENCES} "/" ${PARALLELISM} ") + 1" | bc`
