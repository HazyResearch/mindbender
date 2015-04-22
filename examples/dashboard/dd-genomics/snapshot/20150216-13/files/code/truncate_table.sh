#! /bin/sh
#
# Empty the specified table
#
# First argument is the database name
# Second argument is the table to empty
#
if [ $# -ne 2 ]; then
	echo "$0: ERROR: wrong number of arguments" >&2
	echo "$0: USAGE: $0 DB TABLE" >&2
	exit 1
fi

SQL_COMMAND_FILE=`mktemp /tmp/dft.XXXXX` || exit 1
echo "TRUNCATE TABLE $2;" >> ${SQL_COMMAND_FILE}
psql -X --set ON_ERROR_STOP=1 -d $1 -f ${SQL_COMMAND_FILE} || exit 1
rm ${SQL_COMMAND_FILE}

