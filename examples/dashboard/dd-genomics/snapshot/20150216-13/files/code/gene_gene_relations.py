#! /usr/bin/env python3

import fileinput
import re

from dstruct.Mention import Mention
from dstruct.Sentence import Sentence
from dstruct.Relation import Relation
from helper.dictionaries import load_dict
from helper.easierlife import get_dict_from_TSVline, no_op, TSVstring2bool, \
    TSVstring2list


# Add features
# 20141125 As of now, we use the same features from the gene/hpoterm relation
# extractor.
# TODO Look at Emily's code to understand what features to add
def add_features(relation, gene_1_mention, gene_2_mention, sentence):
    # Find the start/end indices of the mentions composing the relation
    gene_1_start = gene_1_mention.wordidxs[0]
    gene_2_start = gene_2_mention.wordidxs[0]
    gene_1_end = gene_1_mention.wordidxs[-1]
    gene_2_end = gene_2_mention.wordidxs[-1]
    limits = sorted((gene_1_start, gene_2_start, gene_1_end, gene_2_end))
    start = limits[0]
    betw_start = limits[1]
    betw_end = limits[2]
    end = limits[3]
    # If the gene comes first, we do not prefix, otherwise we do.
    # TODO We should think about it because it may not be necessary: the order
    # shouldn't really matter, but I may be wrong. 
    # TODO We should also be careful when specifying the input query, to avoid
    # creating first on one order and then on the other. 
    if start == gene_1_start:
        inv = ""
    else:
        inv = "INV_"

    # Verbs between the mentions
    # A lot of this comes from Emily's code
    ws = []
    verbs_between = []
    minl_gene_1 = 100
    minp_gene_1 = None
    minw_gene_1 = None
    mini_gene_1 = None
    minl_gene_2 = 100
    minp_gene_2 = None
    minw_gene_2 = None
    mini_gene_2 = None
    neg_found = False
    # Emily's code was only looking at the words between the mentions, but it
    # is more correct (in my opinion) to look all the words, as in the
    # dependency path there could be words that are close to both mentions but
    # not between them
    #for i in range(betw_start+1, betw_end):
    for i in range(len(sentences.words)):
        if "," not in sentence.words[i].lemma:
            ws.append(sentence.words[i].lemma)
            # Feature for separation between entities
            # TODO Think about merging these?
            if "while" == sentence.words[i].lemma:
                relation.add_feature("SEP_BY_[while]")
            if "whereas" == sentence.words[i].lemma:
                relation.add_feature("SEP_BY_[whereas]")
        # The filtering of the brackets and commas is from Emily's code. I'm
        # not sure it is actually needed, but it won't hurt.
        if re.search('^VB[A-Z]*', sentence.words[i].pos) and \
                sentence.words[i].word != "{" and \
                sentence.words[i].word != "}" and \
                "," not in sentence.words[i].word:
            p_gene_1 = sentence.get_word_dep_path(betw_start,
                    sentence.words[i].in_sent_idx)
            p_gene_2 = sentence.get_word_dep_path(
                    sentence.words[i].in_sent_idx, betw_end)
            if len(p_gene_1) < minl_gene_1:
                minl_gene_1 = len(p_gene_1)
                minp_gene_1 = p_gene_1
                minw_gene_1 = sentence.words[i].lemma
                mini_gene_1 = sentence.words[i].in_sent_idx
            if len(p_gene_2) < minl_gene_2:
                minl_gene_2 = len(p_gene_2)
                minp_gene_2 = p_gene_2
                minw_gene_2 = sentence.words[i].lemma
                mini_gene_2 = sentence.words[i].in_sent_idx
            # Look for negation.
            if i > 0:
                if sentence.words[i-1].lemma in ["no", "not", "neither", "nor"]:
                    if i < betw_end - 2:
                        neg_found = True
                        relation.add_feature(inv + "NEG_VERB_[" +
                                sentence.words[i-1].word + "]-" +
                                sentence.words[i].lemma)
                elif sentence.words[i] != "{" and sentence.words[i] != "}":
                    verbs_between.append(sentence.words[i].lemma)
    # TODO This idea of 'high_quality_verb' is taken from Emily's code, but
    # it's still not clear to me what it implies
    high_quality_verb = False
    if len(verbs_between) == 1 and not neg_found:
        relation.add_feature(inv + "SINGLE_VERB_[%s]" % verbs_between[0])
        if verbs_between[0] in ["interact", "associate", "bind", "regulate", "phosporylate", "phosphorylated"]:
                high_quality_verb = True
    else:
        for verb in verbs_between:
            relation.add_feature(inv + "VERB_[%s]" % verb)
    if mini_gene_2 == mini_gene_1 and mini_gene_1 != None and len(minp_gene_1) < 50: # and "," not in minw_gene_1:
        # feature = inv + 'MIN_VERB_[' + minw_gene_1 + ']' + minp_gene_1
        # features.append(feature)
        feature = inv + 'MIN_VERB_[' + minw_gene_1 + ']'
        relation.add_feature(feature)
    else:
        if mini_gene_1 != None:
            # feature = 'MIN_VERB_gene_1_[' + minw_gene_1 + ']' + minp_gene_1
            # relation.add_feature(feature)
            feature = inv + 'MIN_VERB_GENE_1_[' + minw_gene_1 + ']'
            relation.add_feature(feature)
        if mini_gene_2 != None:
            # feature = 'MIN_VERB_gene_2_[' + minw_gene_2 + ']' + minp_gene_2)
            # relation.add_feature(feature)
            feature = inv + 'MIN_VERB_GENE_2_[' + minw_gene_2 + ']'
            relation.add_feature(feature)
    # Shortest dependency path between the two mentions
    relation.add_feature(inv + "DEP_PATH_[" + sentence.dep_path(gene_1_mention,
        gene_2_mention) + "]")
    # The sequence of lemmas between the two mentions
    if len(ws) < 7 and len(ws) > 0 and "{" not in ws and "}" not in ws and \
            "\"" not in ws and "/" not in ws and "\\" not in ws and \
            "," not in ws and \
            " ".join(ws) not in ["_ and _", "and", "or",  "_ or _"]:
            relation.add_feature(inv + "WORD_SEQ_[%s]" % " ".join(ws))
    # Number of words between the mentions
    relation.add_feature(inv + "WORD_SEQ_LEN_[%d]" % len(ws))
    # The sequence of lemmas between the two mentions but using the NERs, if
    # present
    seq_list = []
    for word in sentence.words[betw_start+1:betw_end]:
        if word.ner != "O":
            seq_list.append(word.ner)
        else:
            seq_list.append(word.lemma)
    seq = "_".join(seq_list)
    relation.add_feature(inv + "WORD_SEQ_NER_[" + seq + "]")
    # Lemmas on the left and on the right
    if gene_1_start > 0:
        relation.add_feature("GENE_1_NGRAM_LEFT_1_[" +
            sentence.words[gene_1_start-1].lemma + "]")
    if gene_1_end < len(sentence.words) - 1:
        relation.add_feature("GENE_1_NGRAM_RIGHT_1_[" +
            sentence.words[gene_1_end+1].lemma + "]")
    if gene_2_start > 0:
        relation.add_feature("GENE_2_NGRAM_LEFT_1_[" +
            sentence.words[gene_2_start-1].lemma + "]")
    if gene_2_end < len(sentence.words) - 1:
        relation.add_feature("GENE_2_NGRAM_RIGHT_1_[" +
            sentence.words[gene_2_end+1].lemma + "]")


if __name__ == "__main__":
    # Process input
    with fileinput.input() as input_files:
        for line in input_files:
            # Parse the TSV line
            line_dict = get_dict_from_TSVline(
                line, ["doc_id", "sent_id", "wordidxs", "words", "poses",
                       "ners", "lemmas", "dep_paths", "dep_parents",
                       "bounding_boxes", "gene_1_entity", "gene_1_wordidxs",
                       "gene_1_is_correct", "gene_1_type",
                       "gene_2_entity", "gene_2_wordidxs",
                       "gene_2_is_correct", "gene_2_type"],
                [no_op, int, lambda x: TSVstring2list(x, int), TSVstring2list,
                    TSVstring2list, TSVstring2list, TSVstring2list,
                    TSVstring2list, lambda x: TSVstring2list(x, int),
                    TSVstring2list, no_op, lambda x: TSVstring2list(x, int),
                    TSVstring2bool, no_op, no_op, lambda x: TSVstring2list(x,
                    int), TSVstring2bool, no_op])
            # Create the sentence object where the two mentions appear
            sentence = Sentence(
                line_dict["doc_id"], line_dict["sent_id"],
                line_dict["wordidxs"], line_dict["words"], line_dict["poses"],
                line_dict["ners"], line_dict["lemmas"], line_dict["dep_paths"],
                line_dict["dep_parents"], line_dict["bounding_boxes"])
            # Create the mentions
            gene_1_mention = Mention(
                "GENE", line_dict["gene_1_entity"],
                [sentence.words[j] for j in line_dict["gene_1_wordidxs"]])
            gene_1_mention.is_correct = line_dict["gene_1_is_correct"]
            gene_1_mention.type = line_dict["gene_1_type"]
            gene_2_mention = Mention(
                "GENE", line_dict["gene_2_entity"],
                [sentence.words[j] for j in line_dict["gene_2_wordidxs"]])
            gene_2_mention.is_correct = line_dict["gene_2_is_correct"]
            gene_2_mention.type = line_dict["gene_2_type"]
            # If the word indexes do not overlap, create the relation candidate
            # TODO there may be other cases. Check with Emily.
            if not set(line_dict["gene_1_wordidxs"]) & \
                    set(line_dict["gene_2_wordidxs"]):
                relation = Relation(
                    "GENEGENE", gene_1_mention, gene_2_mention)
                # Add features
                add_features(relation, gene_1_mention, gene_2_mention,
                            sentence)
                # Supervise
                # One of the two mentions (or both) is labelled as False
                # We do not create a copy in this case because there will
                # already be an unsupervised copy built on the unsupervised
                # copies of the mentions.
                if gene_1_mention.is_correct is False or \
                        gene_2_mention.is_correct is False:
                    relation.is_correct = False
                    relation.type = "GENEGENE_SUP_F"
                # TODO Check in Emily's code how to supervise as True
                # Print!
                print(relation.tsv_dump())
