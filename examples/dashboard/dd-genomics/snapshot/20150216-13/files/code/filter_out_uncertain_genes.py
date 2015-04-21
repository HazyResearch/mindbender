#! /usr/bin/env python3
#
# Takes as first and only argument a dump obtained using get_dump.sql and
# remove the entries where the gene symbol can be used to express multiple
# genes.

import sys

if len(sys.argv) != 2:
    sys.stderr.write("USAGE: {} dump.tsv\n".format(sys.argv[0]))
    sys.exit(1)

with open(sys.argv[1], 'rt') as dump:
    skipped = 0
    for line in dump:
        tokens = line.strip().split("\t")
        gene_entity = tokens[1]
        if "|" not in gene_entity and "\\N" not in gene_entity:
            print(line.strip())
        else:
            skipped += 1
sys.stderr.write("skipped: {}\n".format(skipped))
