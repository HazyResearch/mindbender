#! /usr/bin/env python3

import fileinput
import random
import re

from dstruct.Mention import Mention
from dstruct.Sentence import Sentence
from dstruct.Relation import Relation
from helper.dictionaries import load_dict
from helper.easierlife import get_dict_from_TSVline, no_op, TSVstring2list

# Load the gene<->hpoterm dictionary
genehpoterms_dict = load_dict("genehpoterms")


# Supervise the candidates
def supervise(relation, gene_mention, hpoterm_mention, sentence):
    # One of the two mentions is labelled as False
    if gene_mention.is_correct is False and \
            hpoterm_mention.is_correct is not False:
        relation.is_correct = False
        relation.type = "GENEPHENO_SUP_F_G"
    elif hpoterm_mention.is_correct is False and \
            gene_mention.is_correct is not False:
        relation.is_correct = False
        relation.type = "GENEPHENO_SUP_F_H"
    elif hpoterm_mention.is_correct is False and \
            gene_mention.is_correct is False:
        relation.is_correct = False
        relation.type = "GENEPHENO_SUP_F_GH"
    else:
        # Present in the existing HPO mapping
        in_mapping = False
        hpo_entity_id = hpoterm_mention.entity.split("|")[0]
        if frozenset([gene_mention.words[0].word, hpo_entity_id]) in \
                genehpoterms_dict:
            in_mapping = True
        else:
            for gene in gene_mention.entity.split("|"):
                if frozenset([gene, hpo_entity_id]) in \
                        genehpoterms_dict:
                    in_mapping = True
                    break
        if in_mapping:
            relation.is_correct = True
            relation.type = "GENEPHENO_SUP_MAP"


if __name__ == "__main__":
    # Process input
    with fileinput.input() as input_files:
        for line in input_files:
            # Parse the TSV line
            line_dict = get_dict_from_TSVline(
                line, ["doc_id", "sent_id", "wordidxs", "words", "poses",
                       "ners", "lemmas", "dep_paths", "dep_parents",
                       "bounding_boxes", "gene_entities", "gene_wordidxss",
                       "gene_is_corrects", "gene_types",
                       "hpoterm_entities", "hpoterm_wordidxss",
                       "hpoterm_is_corrects", "hpoterm_types"],
                [no_op, int, lambda x: TSVstring2list(x, int), TSVstring2list,
                 TSVstring2list, TSVstring2list, TSVstring2list,
                 TSVstring2list, lambda x: TSVstring2list(x, int),
                 TSVstring2list,  # these are for the sentence
                 TSVstring2list, lambda x: TSVstring2list(x, sep="!~!"),
                 TSVstring2list, TSVstring2list,  # these are for the genes
                 TSVstring2list, lambda x: TSVstring2list(x, sep="!~!"),
                 TSVstring2list, TSVstring2list,  # these are for the HPO
                 ])
            # Remove the genes that are unsupervised copies or duplicates
            supervised_idxs = set()
            unsupervised_idxs = set()
            for i in range(len(line_dict["gene_is_corrects"])):
                if line_dict["gene_is_corrects"][i] == "n":
                    unsupervised_idxs.add(i)
                else:
                    if line_dict["gene_types"][i] != "GENE_SUP_contr_2":
                        # The above condition is to avoid duplicates
                        supervised_idxs.add(i)
            survived_unsuperv_idxs = set()
            for i in unsupervised_idxs:
                wordidxs = line_dict["gene_wordidxss"][i]
                found = False
                for j in supervised_idxs:
                    if line_dict["gene_wordidxss"][j] == wordidxs:
                        found = True
                        break
                if not found:
                    survived_unsuperv_idxs.add(i)
            to_keep = sorted(survived_unsuperv_idxs | supervised_idxs)
            new_gene_entities = []
            new_gene_wordidxss = []
            new_gene_is_corrects = []
            new_gene_types = []
            for i in to_keep:
                new_gene_entities.append(line_dict["gene_entities"][i])
                new_gene_wordidxss.append(line_dict["gene_wordidxss"][i])
                new_gene_is_corrects.append(line_dict["gene_is_corrects"][i])
                new_gene_types.append(line_dict["gene_types"][i])
            line_dict["gene_entities"] = new_gene_entities
            line_dict["gene_wordidxss"] = new_gene_wordidxss
            line_dict["gene_is_corrects"] = new_gene_is_corrects
            line_dict["gene_types"] = new_gene_types
            # Remove the hpoterms that are unsupervised copies
            supervised_idxs = set()
            unsupervised_idxs = set()
            for i in range(len(line_dict["hpoterm_is_corrects"])):
                if line_dict["hpoterm_is_corrects"][i] == "n":
                    unsupervised_idxs.add(i)
                else:
                    supervised_idxs.add(i)
            survived_unsuperv_idxs = set()
            for i in unsupervised_idxs:
                wordidxs = line_dict["hpoterm_wordidxss"][i]
                found = False
                for j in supervised_idxs:
                    if line_dict["hpoterm_wordidxss"][j] == wordidxs:
                        found = True
                        break
                if not found:
                    survived_unsuperv_idxs.add(i)
            to_keep = sorted(survived_unsuperv_idxs | supervised_idxs)
            new_hpoterm_entities = []
            new_hpoterm_wordidxss = []
            new_hpoterm_is_corrects = []
            new_hpoterm_types = []
            for i in to_keep:
                new_hpoterm_entities.append(line_dict["hpoterm_entities"][i])
                new_hpoterm_wordidxss.append(line_dict["hpoterm_wordidxss"][i])
                new_hpoterm_is_corrects.append(
                    line_dict["hpoterm_is_corrects"][i])
                new_hpoterm_types.append(line_dict["hpoterm_types"][i])
            line_dict["hpoterm_entities"] = new_hpoterm_entities
            line_dict["hpoterm_wordidxss"] = new_hpoterm_wordidxss
            line_dict["hpoterm_is_corrects"] = new_hpoterm_is_corrects
            line_dict["hpoterm_types"] = new_hpoterm_types
            # Create the sentence object where the two mentions appear
            sentence = Sentence(
                line_dict["doc_id"], line_dict["sent_id"],
                line_dict["wordidxs"], line_dict["words"], line_dict["poses"],
                line_dict["ners"], line_dict["lemmas"], line_dict["dep_paths"],
                line_dict["dep_parents"], line_dict["bounding_boxes"])
            # Skip weird sentences
            if sentence.is_weird():
                continue
            gene_mentions = []
            hpoterm_mentions = []
            positive_relations = []
            gene_wordidxs = set()
            hpoterm_wordidxs = set()
            # Iterate over each pair of (gene,phenotype) mentions
            for g_idx in range(len(line_dict["gene_is_corrects"])):
                g_wordidxs = TSVstring2list(
                    line_dict["gene_wordidxss"][g_idx], int)
                for idx in g_wordidxs:
                    gene_wordidxs.add(idx)
                gene_mention = Mention(
                    "GENE", line_dict["gene_entities"][g_idx],
                    [sentence.words[j] for j in g_wordidxs])
                if line_dict["gene_is_corrects"][g_idx] == "n":
                    gene_mention.is_correct = None
                elif line_dict["gene_is_corrects"][g_idx] == "f":
                    gene_mention.is_correct = False
                elif line_dict["gene_is_corrects"][g_idx] == "t":
                    gene_mention.is_correct = True
                else:
                    assert False
                gene_mention.type = line_dict["gene_types"][g_idx]
                assert not gene_mention.type.endswith("_UNSUP")
                gene_mentions.append(gene_mention)
                for h_idx in range(len(line_dict["hpoterm_is_corrects"])):
                    h_wordidxs = TSVstring2list(
                        line_dict["hpoterm_wordidxss"][h_idx], int)
                    for idx in h_wordidxs:
                        hpoterm_wordidxs.add(idx)
                    hpoterm_mention = Mention(
                        "hpoterm", line_dict["hpoterm_entities"][h_idx],
                        [sentence.words[j] for j in h_wordidxs])
                    if line_dict["hpoterm_is_corrects"][h_idx] == "n":
                        hpoterm_mention.is_correct = None
                    elif line_dict["hpoterm_is_corrects"][h_idx] == "f":
                        hpoterm_mention.is_correct = False
                    elif line_dict["hpoterm_is_corrects"][h_idx] == "t":
                        hpoterm_mention.is_correct = True
                    else:
                        assert False
                    hpoterm_mention.type = line_dict["hpoterm_types"][h_idx]
                    assert not hpoterm_mention.type.endswith("_UNSUP")
                    hpoterm_mentions.append(hpoterm_mention)
                    # Skip if the word indexes overlab
                    if set(g_wordidxs) & set(h_wordidxs):
                        continue
                    # Skip if the mentions are too far away
                    gene_start = gene_mention.wordidxs[0]
                    hpoterm_start = hpoterm_mention.wordidxs[0]
                    gene_end = gene_mention.wordidxs[-1]
                    hpoterm_end = hpoterm_mention.wordidxs[-1]
                    limits = sorted(
                        (gene_start, hpoterm_start, gene_end, hpoterm_end))
                    start = limits[0]
                    betw_start = limits[1]
                    betw_end = limits[2]
                    if betw_end - betw_start > 50:
                        continue
                    relation = Relation(
                        "GENEPHENO", gene_mention, hpoterm_mention)
                    # Supervise
                    supervise(relation, gene_mention, hpoterm_mention,
                              sentence)
                    if relation.is_correct:
                        positive_relations.append(
                            (gene_mention, hpoterm_mention))
                    # Print!
                    print(relation.tsv_dump())
            # Create some artificial negative examples:
            # for each (gene, phenotype) pair that is labelled as positive
            # example, select one word w in the same sentence that (1) is not a
            # gene mention candidate and (2) is not a phenotype mention
            # candidate, add (gene, w) and (w, phenotype) as negative example
            avail_wordidxs = (
                set(line_dict["wordidxs"]) - set(hpoterm_wordidxs)) - \
                set(gene_wordidxs)
            avail_wordidxs = list(avail_wordidxs)
            if len(avail_wordidxs) > 0:
                fake_rels = []
                for (gene_mention, hpoterm_mention) in positive_relations:
                    other_word = sentence.words[random.choice(avail_wordidxs)]
                    fake_gene_mention = Mention(
                        "FAKE_GENE", other_word.lemma, [other_word, ])
                    fake_hpo_mention = Mention(
                        "FAKE_HPOTERM", other_word.lemma, [other_word, ])
                    fake_rel_1 = Relation(
                        "GENEPHENO_SUP_POSFAKEGENE", fake_gene_mention,
                        hpoterm_mention)
                    fake_rel_2 = Relation(
                        "GENEPHENO_SUP_POSFAKEHPO", gene_mention,
                        fake_hpo_mention)
                    fake_rel_1.is_correct = False
                    fake_rel_2.is_correct = False
                    # Print!
                    print(fake_rel_1.tsv_dump())
                    print(fake_rel_2.tsv_dump())
            # Create more artificial negative examples:
            # for each gene candidate G in the sentence, if the pattern G
            # <Verb> X appears in the same sentence and X is not a phenotype
            # mention candidate, add (gene, X) as negative examples
            for gene_mention in gene_mentions:
                try:
                    next_word = sentence.words[gene_mention.wordidxs[-1] + 1]
                except IndexError:
                    continue
                if re.search('^VB[A-Z]*$', next_word.pos) and \
                        next_word.word not in ["{", "}", "(", ")", "[", "]"]:
                    try:
                        after_next_word = sentence.words[
                            next_word.in_sent_idx + 1]
                    except IndexError:
                        continue
                    if after_next_word.in_sent_idx in hpoterm_wordidxs:
                        continue
                    fake_hpo_mention = Mention(
                        "FAKE_HPOTERM", after_next_word.lemma,
                        [after_next_word, ])
                    fake_rel = Relation(
                        "GENEPHENO_SUP_FAKEHPO", gene_mention,
                        fake_hpo_mention)
                    fake_rel.is_correct = False
                    print(fake_rel.tsv_dump())
            # Create more artificial negative examples:
            # as before but for phenotypes
            for hpo_mention in hpoterm_mentions:
                try:
                    next_word = sentence.words[hpo_mention.wordidxs[-1] + 1]
                except IndexError:
                    continue
                if re.search('^VB[A-Z]*$', next_word.pos) and \
                        next_word.word not in ["{", "}", "(", ")", "[", "]"]:
                    try:
                        after_next_word = sentence.words[
                            next_word.in_sent_idx + 1]
                    except IndexError:
                        continue
                    if after_next_word.in_sent_idx in gene_wordidxs:
                        continue
                    fake_gene_mention = Mention(
                        "FAKE_GENE", after_next_word.lemma,
                        [after_next_word, ])
                    fake_rel = Relation(
                        "GENEPHENO_SUP_FAKEGENE", fake_gene_mention,
                        hpo_mention)
                    fake_rel.is_correct = False
                    print(fake_rel.tsv_dump())
