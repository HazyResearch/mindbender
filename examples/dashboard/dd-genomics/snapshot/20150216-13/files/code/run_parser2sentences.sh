#! /bin/sh
#
# Call parser2sentences with the correct paths
#
# First argument is base directory
# Second argument is output file

PARSER_OUTPUT_DIR="data/parser_output"
PARSER_TO_SENTENCES_SCRIPT="code/parser2sentences.py"

if [ $# -ne 2 ]; then
	echo "$0: ERROR: wrong number of arguments" >&2
	echo "$0: USAGE: $0 BASEDIR OUTPUT_FILE" >&2
	exit 1
fi

if [ ! -x $1 ]; then
	echo "$0: ERROR: can not traverse base directory" >&2
	exit 1
fi

${1}/${PARSER_TO_SENTENCES_SCRIPT} ${1}/${PARSER_OUTPUT_DIR}/* > ${2} || exit 1

