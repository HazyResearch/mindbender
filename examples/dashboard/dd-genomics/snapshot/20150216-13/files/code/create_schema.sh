#! /bin/sh
# 
# Create the database tables
# 
# First argument is the application base directory,
# Second argument is the database name

if [ $# -ne 2 ]; then
	echo "$0: ERROR: wrong number of arguments" >&2
	echo "$0: USAGE: $0 APP_BASE_DIR DB_NAME" >&2
	exit 1
fi

SCHEMA_FILE="$1/code/schema.sql"
if [ ! -r ${SCHEMA_FILE} ]; then
	echo "$0: ERROR: schema file is not readable" >&2
	exit 1
fi

psql -X --set ON_ERROR_STOP=1 -d $2 -f ${SCHEMA_FILE} 

