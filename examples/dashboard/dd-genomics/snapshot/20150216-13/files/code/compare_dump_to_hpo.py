#! /usr/bin/env python3
#
# Perform comparision between existing HPO mapping and dump from DeepDive
#
# Take the output from canonicalize.py

import sys

if len(sys.argv) != 3:
    sys.stderr.write("USAGE: {} hpo dump\n".format(sys.argv[0]))
    sys.exit(1)

hpo_genes = set()
hpo_ids = set()
hpo_mappings = set()
with open(sys.argv[1], 'rt') as hpo:
    for line in hpo:
        tokens = line.strip().split("\t")
        gene = tokens[0]
        hpo_id = tokens[1]
        assert hpo_id.startswith("HP:")
        hpo_genes.add(gene)
        hpo_ids.add(hpo_id)
        hpo_mappings.add("_".join((gene, hpo_id)))

dump_genes = set()
dump_ids = set()
dump_mappings = set()
relation_ids = dict()
with open(sys.argv[2], 'rt') as dump:
    for line in dump:
        tokens = line.strip().split("\t")
        relation_id = tokens[0]
        gene = tokens[1]
        assert "\\N" not in gene
        hpo_id = tokens[2]
        assert hpo_id.startswith("HP:")
        dump_genes.add(gene)
        dump_ids.add(hpo_id)
        rel_string = "_".join((gene, hpo_id))
        dump_mappings.add(rel_string)
        if rel_string not in relation_ids:
            relation_ids[rel_string] = set()
        relation_ids[rel_string].add(relation_id)


print("### HPO (existing mapping) ###")
print("Non-zero Entries: {}".format(len(hpo_mappings)))
print("\"Covered\" Genes: {}".format(len(hpo_genes)))
print("\"Covered\" Phenotypes: {}".format(len(hpo_ids)))
print("### DeepDive Dump ###")
print("Non-zero Entries: {}".format(len(dump_mappings)))
print("\"Covered\" Genes: {}".format(len(dump_genes)))
print("\"Covered\" Phenotypes: {}".format(len(dump_ids)))
print("### Comparison ###")
print("Non-zero Entries in both: {}".format(
    len(hpo_mappings & dump_mappings)))
print("Non-zero Entries only in HPO: {}".format(
    len(hpo_mappings - dump_mappings)))
print("Non-zero Entries only in DD Dump: {}".format(
    len(dump_mappings - hpo_mappings)))
print("\"Covered\" Genes in both: {}".format(len(hpo_genes & dump_genes)))
print("\"Covered\" Genes only in HPO: {}".format(len(hpo_genes - dump_genes)))
print("\"Covered\" Genes only in DD Dump: {}".format(
    len(dump_genes - hpo_genes)))
print("\"Covered\" Phenotypes in both: {}".format(len(hpo_ids & dump_ids)))
print("\"Covered\" Phenotypes only in HPO: {}".format(len(hpo_ids - dump_ids)))
print("\"Covered\" Phenotypes only in DD Dump: {}".format(
    len(dump_ids - hpo_ids)))

print("#######")
printed_rels = set()
for new_rel in dump_mappings - hpo_mappings:
    for rel_id in set(relation_ids[new_rel]) - printed_rels:
        print(rel_id)
        printed_rels.add(rel_id)
