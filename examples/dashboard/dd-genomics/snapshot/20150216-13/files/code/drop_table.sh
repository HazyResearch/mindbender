#! /bin/sh
#
# Drop the specified table
#
# First argument is the database name
# Second argument is the table to drop
#
if [ $# -ne 2 ]; then
	echo "$0: ERROR: wrong number of arguments" >&2
	echo "$0: USAGE: $0 DB TABLE" >&2
	exit 1
fi

SQL_COMMAND_FILE=`mktemp /tmp/dft.XXXXX` || exit 1
echo "DROP TABLE IF EXISTS $2 CASCADE;" >> ${SQL_COMMAND_FILE}
psql -X --set ON_ERROR_STOP=1 -d $1 -f ${SQL_COMMAND_FILE} || exit 1
rm ${SQL_COMMAND_FILE}

