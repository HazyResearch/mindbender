#!/usr/bin/env bash
# variables/stats -- Report statistics of a single variable
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2015-02-08
set -eu

# parameters
: ${table:?name of the table that has the variable column}
: ${column:?name of the column of the variable}
: ${expectation_threshold:=0.9}
: ${words_column:=words} # name of the column for the words of a mention
: ${num_top_mentions:=10} # limit the number of most frequent mentions extracted
: ${doc_id_column:=doc_id} # name of the column for the document id of a mention

: >README.md

echo "Collecting basic counts of variable ${table}.${column}..."
num_total=$(run-sql "SELECT COUNT(*) FROM ${table}")
num_positive_examples=$(run-sql "SELECT COUNT(*) FROM ${table} WHERE ${column} = true ")
num_negative_examples=$(run-sql "SELECT COUNT(*) FROM ${table} WHERE ${column} = false")
num_queries=$(( $num_total - $num_positive_examples - $num_negative_examples ))
num_mentions_above_threshold=$(run-sql "
    SELECT COUNT(*)
    FROM ${table}_${column}_inference
    WHERE expectation > ${expectation_threshold}
")

if [[ -n "$words_column" ]]; then
    echo "Counting distinct mentions of variable ${table}.${column}..."
    num_distinct_mentions_above_threshold=$(run-sql "
        SELECT COUNT(DISTINCT ${words_column})
        FROM ${table}_${column}_inference
        WHERE expectation > ${expectation_threshold}
    ")

    # most frequent mentions
    echo "Finding top $num_top_mentions most frequent mentions of variable ${table}.${column}..."
    run-sql "
        SELECT ${words_column}, COUNT(*) AS count
        FROM ${table}_${column}_inference
        WHERE expectation > ${expectation_threshold}
        GROUP BY ${words_column}
        ORDER BY count DESC, ${words_column}
        LIMIT $num_top_mentions
    " CSV HEADER >top_mentions.csv

    # TODO Good-Turing estimator
fi

if [[ -n "$doc_id_column" ]]; then
    echo "Counting number of documents with mentions of variable ${table}.${column}..."
    num_documents_with_mentions_above_threshold=$(run-sql "
        SELECT COUNT(DISTINCT ${doc_id_column})
        FROM ${table}_${column}_inference
        WHERE expectation > ${expectation_threshold}
    ")
fi


expectation_threshold_formatted=$(printf "%.2f" $expectation_threshold)

{
cat <<EOF
## Variable ${table}.${column}

* **$(printf "%'d" $num_total)** mention candidates
    * **$(printf "%'d" $num_positive_examples)** positive examples
    * **$(printf "%'d" $num_negative_examples)** negative examples
    * **$(printf "%'d" $num_queries)** query variables
* **$(printf "%'d" $num_mentions_above_threshold)** mentions with expectation > $expectation_threshold_formatted
EOF

if [[ -n "$words_column" ]]; then
    cat <<-EOF
	* **$(printf "%'d" $num_distinct_mentions_above_threshold)** distinct mentions with expectation > $expectation_threshold_formatted
	EOF
fi

if [[ -n "$doc_id_column" ]]; then
    cat <<-EOF
	* **$(printf "%'d" $num_documents_with_mentions_above_threshold)** documents with mentions with expectation > $expectation_threshold_formatted
	EOF
fi

echo  # end of list

if [[ -n "$words_column" ]]; then
    cat <<-EOF
	### Most frequent mentions
	EOF
    html-table-for top_mentions.csv
fi
} >README.md

cat >report.json <<-EOF
{
    "num_total": $num_total,
    "num_positive_examples": $num_positive_examples,
    "num_negative_examples": $num_negative_examples,
    "num_queries": $num_queries,
    ${words_column:+"num_distinct_mentions_above_threshold": $num_distinct_mentions_above_threshold,}
    ${doc_id_column:+"num_documents_with_mentions_above_threshold": $num_documents_with_mentions_above_threshold,}
    "num_mentions_above_threshold": $num_mentions_above_threshold
}
EOF
