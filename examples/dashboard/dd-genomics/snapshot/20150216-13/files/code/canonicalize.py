#! /usr/bin/env python3
#
# Canonicalize a dump using the HPO dag
#
# Use the output of filter_out_uncertain_genes.py


import sys

from helper.dictionaries import load_dict

if len(sys.argv) != 2:
    sys.stderr.write("USAGE: {} dump.tsv\n".format(sys.argv[0]))
    sys.exit(1)

hpoancestors = load_dict("hpoancestors")

with open(sys.argv[1], 'rt') as dump:
    for line in dump:
        tokens = line.strip().split("\t")
        relation_id = tokens[0]
        gene_entity = tokens[1]
        hpo_entity = tokens[3]
        if "|" not in hpo_entity:
            continue
        hpo_id = hpo_entity.split("|")[0]
        if hpo_id not in hpoancestors:
            continue
        print("{}\t{}\t{}".format(relation_id, gene_entity, hpo_entity))
        for ancestor in hpoancestors[hpo_id]:
            print("{}\t{}\t{}".format(relation_id, gene_entity, ancestor))
