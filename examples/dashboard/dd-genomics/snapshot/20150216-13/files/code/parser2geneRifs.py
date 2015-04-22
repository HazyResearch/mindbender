#! /usr/bin/env python3
#
# Take the json output of the NLPextractor extractor and convert it to TSV that
# we can feed to the database using COPY FROM. The schema of the table is equal
# to the 'sentences' table except for an additional column at the end which is
# the gene that we know the geneRif contains.

import fileinput
import json
import sys

from helper.easierlife import list2TSVarray


if len(sys.argv) < 2:
    sys.stderr.write("USAGE: {} GENE_RIFS_DICT PARSER_OUTPUT [PARSER_OUTPUT [PARSER_OUTPUT [...]]]\n".format(sys.argv[0]))
    sys.exit(1)

genes = []
with open(sys.argv[1], 'rt') as gene_rifs_dict_file:
    for line in gene_rifs_dict_file:
        tokens = line.strip().split("\t")
        genes.append(tokens[1])

with fileinput.input(sys.argv[2:]) as input_files:
    for line in input_files:
        line_dict = json.loads(line)
        doc_id = line_dict["doc_id"]
        sent_id = line_dict["sent_id"]
        words = line_dict["words"]
        wordidxs = [x for x in range(len(words))]
        poses = line_dict["poses"]
        ners = line_dict["ners"]
        lemmas = line_dict["lemmas"]
        dep_paths_orig = line_dict["dep_paths"]
        bounding_boxes = ["empty"] * len(words)

        gene_index = int(doc_id.split("-")[-1])

        # Compute dependency path edge labels and node parents
        dep_paths = ["_"] * len(words)
        dep_parents = [0] * len(words)
        for dep_path in dep_paths_orig:
            tokens = dep_path.split("(")
            dep_parent = int((tokens[1].split(", ")[0]).split("-")[-1]) - 1
            dep_child = int((tokens[1].split(", ")[-1]).split("-")[-1][:-1]) - 1
            dep_paths[dep_child] = tokens[0]
            dep_parents[dep_child] = dep_parent

        print("{}".format("\t".join([doc_id, str(sent_id),
            list2TSVarray(wordidxs), list2TSVarray(words,
                quote=True), list2TSVarray(poses, quote=True),
            list2TSVarray(ners), list2TSVarray(lemmas, quote=True),
            list2TSVarray(dep_paths, quote=True),
            list2TSVarray(dep_parents),
            list2TSVarray(bounding_boxes), genes[gene_index]])))

