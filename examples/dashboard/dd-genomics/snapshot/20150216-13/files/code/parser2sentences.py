#! /usr/bin/env python3
#
# Takes one directory containing parser output files and, for each file in that
# directory, emits TSV lines that can be loaded # in the 'sentences' table
# using the PostgreSQL COPY FROM command.
# 
# Parser output files contain "blocks" which are separated by blank lines. Each
# "block"  is a sentence. Each sentence spans over one or more lines. Each line
# represents a # "word" in the sentence (it can be punctuation, a symbol or
# anything). Each word line has *nine* fields:
# 1: index of the word in the sentence, starting from 1.
# 2: the text of the word as it appears in the document
# 3: Part of Speech (POS) tag of the word (see
#    http://www.computing.dcu.ie/~acahill/tagset.html for a list)
# 4: Named Entity Recognition (NER) tag of the word
# 5: the lemmatized word
# 6: the label on the edge in dependency path between the parent of this word
#    and the word
# 7: the word index of the *parent* of this word in the dependency path. 0
#    means root
# 8: the sentence ID, unique in the document
# 9: the bounding box containing this word in the PDF document. The format is
#    "[pXXXlXXXtXXXrXXXbXXX]," for page, left, top, right, bottom.
#    Alternatively, the bounding box may have format 
#    "[pXXXlXXXtXXXrXXXbXXX, pYYYlYYYtYYYrYYYbYYY]" when the word is split
#    between two lines
# An example line is:
# 1	Genome	NNP	O	Genome	nn	3	SENT_1	[p1l1669t172r1943b234],
#
# This script outputs TSV lines or JSON objects, one per sentence. 
#
# Each TSV line has nine columns. The text in the columns is formatted so that
# the output can be given in input to the PostgreSQL 'COPY FROM' command. The
# columns are the following (between parentheses is the PostgreSQL type for the column):
# 1: document ID (text)
# 2: sentence ID (int)
# 3: word indexes (int[]). They now start from 0, like an array.
# 4: words, (text[])
# 5: POSes (text[])
# 6: NERs (text[])
# 7: dependency paths (text[])
# 8: dependency parent (int[]) -1 means root, so that each of them is an array index
# 9: bounding boxes (text[])
#
# This script can be spawn subprocesses to increase parallelism, which can be
# useful when having to convert a lot of files. 
#

import json
import os
import os.path
import sys
from multiprocessing import Process

from helper.easierlife import list2TSVarray

def process_files(proc_id, input_files, input_dir, output_dir, mode):
    with open(os.path.realpath("{}/sentences-{}.{}".format(output_dir, proc_id, mode)), 'wt') as out_file:
        for filename in input_files:
            # Docid assumed to be the filename.
            docid = filename
            with open(os.path.realpath(input_dir + "/" + filename), 'rt') as curr_file:
                atEOF = False
                # Check if the file is empty (we are at End of File)
                curr_pos = curr_file.tell()
                curr_file.read(1)
                new_pos = curr_file.tell()
                if new_pos == curr_pos:
                    atEOF = True
                else:
                    curr_file.seek(curr_pos)
                # One iteration of the following loop corresponds to one sentence
                while not atEOF: 
                    sent_id = -1
                    wordidxs = []
                    words = []
                    poses = []
                    ners = []
                    lemmas = []
                    dep_paths = []
                    dep_parents = []
                    bounding_boxes = []
                    curr_line = curr_file.readline().strip()
                    # Sentences are separated by empty lines in the parser output file
                    while curr_line != "":
                        tokens = curr_line.split("\t")
                        if len(tokens) != 9:
                            sys.stderr.write("ERROR: malformed line (wrong number of fields): {}\n".format(curr_line))
                            return 1
                        word_idx, word, pos, ner, lemma, dep_path, dep_parent, word_sent_id, bounding_box = tokens 
                        # Normalize sentence id
                        word_sent_id = int(word_sent_id.replace("SENT_", ""))
                        # assign sentence id if this is the first word of the sentence
                        if sent_id == -1:
                            sent_id = word_sent_id
                        # sanity check for word_sent_id
                        elif sent_id != word_sent_id:
                            sys.stderr.write("ERROR: found word with mismatching sent_id w.r.t. sentence: {} != {}\n".format(word_sent_id, sent_id))
                            return 1
                        # Normalize bounding box, stripping initial '[' and
                        # final '],' and concatenating components
                        bounding_box = bounding_box[1:-2]
                        bounding_box = bounding_box.replace(", ", "-")
                        # Append contents of this line to the sentence arrays
                        wordidxs.append(int(word_idx) - 1) # Start from 0
                        words.append(word) 
                        poses.append(pos)
                        ners.append(ner)
                        lemmas.append(lemma)
                        dep_paths.append(dep_path)
                        # Now "-1" means root and the rest correspond to array indices
                        dep_parents.append(int(dep_parent) - 1) 
                        bounding_boxes.append(bounding_box)
                        # Read the next line
                        curr_line = curr_file.readline().strip()
                    # Write sentence to output
                    if mode == "tsv":
                        out_file.write("{}\n".format("\t".join([docid, str(sent_id),
                            list2TSVarray(wordidxs), list2TSVarray(words,
                                quote=True), list2TSVarray(poses, quote=True),
                            list2TSVarray(ners), list2TSVarray(lemmas, quote=True),
                            list2TSVarray(dep_paths, quote=True),
                            list2TSVarray(dep_parents),
                            list2TSVarray(bounding_boxes)])))
                    elif mode == "json":
                        out_file.write("{}\n".format(json.dumps({ "doc_id": docid, "sent_id": sent_id,
                            "wordidxs": wordidxs, "words": words, "poses": poses,
                            "ners": ners, "lemmas": lemmas, "dep_paths": dep_paths,
                            "dep_parents": dep_parents, "bounding_boxes":
                            bounding_boxes})))
                    # Check if we are at End of File
                    curr_pos = curr_file.tell()
                    curr_file.read(1)
                    new_pos = curr_file.tell()
                    if new_pos == curr_pos:
                        atEOF = True
                    else:
                        curr_file.seek(curr_pos)


# Process the input files. Output can be either tsv or json
def main():
    script_name = os.path.basename(__file__)
    # Check
    if len(sys.argv) != 5:
        sys.stderr.write("USAGE: {} MODE PARALLELISM INPUTDIR OUTPUTDIR\n".format(script_name))
        return 1

    parser_files = os.listdir(os.path.abspath(os.path.realpath(sys.argv[3])))
    parallelism = int(sys.argv[2])
    mode = sys.argv[1]

    for i in range(parallelism):
        files = []
        for j in range(len(parser_files)):
            if j % parallelism == i:
                files.append(parser_files[j])
        p = Process(target = process_files, args = (i, files,
            os.path.abspath(os.path.realpath(sys.argv[3])),
            os.path.abspath(os.path.realpath(sys.argv[4])), mode))
        p.start()

    return 0


if __name__ == "__main__":
    sys.exit(main())

