#! /bin/sh
#
# Link the parser outputs contained in the article directory to a file named
# like the article
#
# First argument is the directory containing the article directories
# Second argument is the directory where the links should be created.

if [ $# -ne 2 ]; then
	echo "$0: ERROR: wrong number of arguments" >&2
	echo "$0: USAGE: $0 INPUT_DIR OUTPUT_DIR" >&2
	exit 1
fi

if [ \( ! -r $1 \) -o \( ! -x $1 \) ]; then
	echo "$0: ERROR: can not traverse input directory" >&2
	exit 1
fi

mkdir -p $2

for article_filename in `find $1 -maxdepth 1 -type d`; do
	# -s : file exists and has size larger than 0
	if [ -s ${article_filename}/input.text ]; then
		NAME=`basename ${article_filename}`
		if [ ! -r $2/${NAME} ]; then
			ln -s `readlink -f ${article_filename}/input.text` $2/${NAME}
		fi
	fi
done

