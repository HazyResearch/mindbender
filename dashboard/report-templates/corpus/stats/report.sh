#!/usr/bin/env bash
# corpus/stats -- Report corpus statistics
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2015-02-08
set -eu

# parameters
: ${table:?name of the table that contains all sentences}
: ${document_id_column:?name of the column that contains the document identifer of each sentence}

# data acquisition
echo Counting number of documents and sentences...
num_documents=$(run-sql " SELECT COUNT(DISTINCT "$document_id_column") FROM $table ")
num_sentences=$(run-sql " SELECT COUNT(*) FROM $table ")


cat >README.md <<EOF
* **$(printf "%'d" $num_documents)** documents
* **$(printf "%'d" $num_sentences)** sentences
EOF


cat >report.json <<EOF
{
    "num_documents": $num_documents,
    "num_sentences": $num_sentences
}
EOF
