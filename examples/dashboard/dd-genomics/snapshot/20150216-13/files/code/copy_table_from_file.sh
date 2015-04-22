#! /bin/sh
#
# Load a TSV file into a table using PostgreSQL COPY FROM command
#
# First argument is the database name
# Second argument is the table name
# Third argument is the path to the TSV file or to a directory containing tsv
# files

abs_real_path () { 
	case "$1" in 
		/*) TSV_FILE_ABS_PATH=`readlink -f $1`
			;;
		*)  TSV_FILE_ABS_PATH=`readlink -f $PWD/$1`
			;;
	esac; 
}

copy_from_file() {
	SQL_COMMAND_FILE=`mktemp /tmp/ctff.XXXXX` || exit 1
	abs_real_path $1
	echo "COPY $TABLE FROM '${TSV_FILE_ABS_PATH}';" > ${SQL_COMMAND_FILE}
	psql -X --set ON_ERROR_STOP=1 -d $DB -f ${SQL_COMMAND_FILE}
	rm ${SQL_COMMAND_FILE}
}

if [ $# -ne 3 ]; then
	echo "$0: ERROR: wrong number of arguments" >&2
	echo "$0: USAGE: $0 DB TABLE FILE/DIR" >&2
	exit 1
fi

if [ ! -r $3 ]; then
	echo "$0: ERROR: TSV file/directory not readable" >&2
	exit 1
fi

DB=$1
TABLE=$2

if [ -d $3 ]; then
	for file in `find $3 -name '*tsv'`; do
		copy_from_file $file
	done
else
	copy_from_file $3
fi
