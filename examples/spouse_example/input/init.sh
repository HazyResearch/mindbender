#!/usr/bin/env bash
# A script for loading DeepDive spouse example data into PostgreSQL database directly from GitHub
set -eux
cd "$(dirname "$0")"

# download some udf code from DeepDive repo
mkdir -p ../udf
download() { curl -fsSRLo ../udf/$1 https://github.com/HazyResearch/deepdive/raw/master/examples/spouse_example/postgres/ddlog/udf/$1; }
download ext_has_spouse.py
download ext_has_spouse_features.py
download ext_people.py

catRemoteBzip2() {
    curl -fsSL "https://github.com/HazyResearch/deepdive/raw/master/examples/spouse_example/data/$1" | bzcat
}

## raw data
# articles
catRemoteBzip2 articles_dump.csv.bz2 | deepdive sql "COPY articles  FROM STDIN CSV"

# preprocessed sentences
catRemoteBzip2 sentences_dump.csv.bz2 |
if [[ -z ${SUBSAMPLE_NUM_SENTENCES:-} ]]; then cat; else head -n ${SUBSAMPLE_NUM_SENTENCES}; fi |
deepdive sql "COPY sentences FROM STDIN CSV"

## data for udfs
# known relationships for distant supervision
catRemoteBzip2 non-spouses.tsv.bz2 >non-spouses.tsv
catRemoteBzip2     spouses.csv.bz2     >spouses.csv


