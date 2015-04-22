#! /bin/bash

export APP_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export DEEPDIVE_HOME="$( cd $APP_HOME && cd ../..  && pwd )"

export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8

source "$APP_HOME/env.sh"
source "$APP_HOME/env_db.sh"

if [ -f $DEEPDIVE_HOME/sbt/sbt ]; then
  echo "DeepDive $DEEPDIVE_HOME"
else
  echo "[ERROR] Could not find sbt in $DEEPDIVE_HOME!"
  exit 1
fi

cd $DEEPDIVE_HOME
sbt "run -c $APP_HOME/application.conf"
