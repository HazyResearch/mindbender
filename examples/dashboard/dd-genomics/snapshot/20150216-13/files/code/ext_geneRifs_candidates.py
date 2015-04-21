#! /usr/bin/env python3
#
# Extract, add features to, and supervise mentions extracted from geneRifs.
#

import fileinput

from dstruct.Sentence import Sentence
from extract_gene_mentions import extract
from helper.easierlife import get_dict_from_TSVline, TSVstring2list, no_op
from helper.dictionaries import load_dict

if __name__ == "__main__":
    # Load the merged genes dictionary
    merged_genes_dict = load_dict("merged_genes")
    # Process the input
    with fileinput.input() as input_files:
        for line in input_files:
            # Parse the TSV line
            line_dict = get_dict_from_TSVline(
                line, ["doc_id", "sent_id", "wordidxs", "words", "gene"],
                [no_op, int, lambda x: TSVstring2list(x, int), TSVstring2list,
                    no_op])
            # Create the Sentence object
            null_list = [None, ] * len(line_dict["wordidxs"])
            sentence = Sentence(
                line_dict["doc_id"], line_dict["sent_id"],
                line_dict["wordidxs"], line_dict["words"], null_list,
                null_list, null_list, null_list, null_list, null_list)
            # This is the 'labelled' gene that we know is in the sentence
            gene = line_dict["gene"]
            # Get the main symbol (or list of symbols) for the labelled gene
            if gene in merged_genes_dict:
                gene = merged_genes_dict[gene]
            else:
                gene = [gene, ]
            # Skip sentences that are "( GENE )", as they give no info about
            # anything.
            if (sentence.words[0].word == "-LRB-" and
                    sentence.words[-1].word == "-RRB-") or \
               (sentence.words[0].word == "-LSB-" and
                    sentence.words[-1].word == "-RSB-"):
                        continue
            # Extract mentions from sentence. This also adds the features
            mentions = extract(sentence)
            # Find the candidate(s) containing the "labelled" gene either in
            # the words or in the entity, and supervise as True and print.
            not_main_mentions = []
            for mention in mentions:
                mention.type = "GENERIFS"
                for g in gene:
                    # If we find the labelled symbol in the words of the
                    # candidate, supervise as true and print
                    if g in mention.words[0].word or \
                            g in mention.entity.split("|"):
                        mention.is_correct = True
                        print(mention.tsv_dump())
                        break
