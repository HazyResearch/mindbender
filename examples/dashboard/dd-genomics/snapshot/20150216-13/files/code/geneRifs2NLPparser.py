#! /usr/bin/env python3
#
# Convert geneRifs file to a file that can be given in input to the NLPparser
# extractor.

import fileinput
import json
import sys

if len(sys.argv) < 2:
    sys.stderr.write("USAGE: {} FILE [FILE [FILE [...]]]\n".format(sys.argv[0]))
    sys.exit(1)

DOCUMENT_ID = "geneRifs-"
i = 0
with fileinput.input() as input_files:
    for line in input_files:
        tokens = line.split("\t")
        line_dict = {"id": DOCUMENT_ID + str(i), "text": tokens[2]}
        print(json.dumps(line_dict))
        i += 1

