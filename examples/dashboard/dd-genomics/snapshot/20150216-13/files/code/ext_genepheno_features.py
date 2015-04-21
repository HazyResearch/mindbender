#! /usr/bin/env python3

import fileinput
import re

from dstruct.Sentence import Sentence
from helper.easierlife import get_dict_from_TSVline, TSVstring2list, no_op, \
    print_feature

import ddlib


def add_features_generic(relation_id, gene_words, pheno_words, sentence):
    # Use the generic feature library (ONLY!)

    obj = dict()
    obj['lemma'] = []
    obj['words'] = []
    obj['ner'] = []
    obj['pos'] = []
    obj['dep_graph'] = []
    for word in sentence.words:
        obj['lemma'].append(word.lemma)
        obj['words'].append(word.word)
        obj['ner'].append(word.ner)
        obj['pos'].append(word.pos)
        obj['dep_graph'].append(
            str(word.dep_parent + 1) + "\t" + word.dep_path + "\t" +
            str(word.in_sent_idx + 1))
    word_obj_list = ddlib.unpack_words(
        obj, lemma='lemma', pos='pos', ner='ner', words='words',
        dep_graph='dep_graph', dep_graph_parser=ddlib.dep_graph_parser_triplet)
    gene_span = ddlib.get_span(gene_words[0].in_sent_idx, len(gene_words))
    pheno_span = ddlib.get_span(pheno_words[0].ins_sent_idx, len(pheno_words))
    features = set()
    for feature in ddlib.get_generic_feature_relation(
            word_obj_list, gene_span, pheno_span):
        features.add(feature)
    for feature in features:
        print_feature(sentence.doc_id, relation_id, feature)


# Add features (few)
def add_features_few(relation, gene_mention, hpoterm_mention, sentence):
    # Find the start/end indices of the mentions composing the relation
    gene_start = gene_mention.wordidxs[0]
    hpoterm_start = hpoterm_mention.wordidxs[0]
    gene_end = gene_mention.wordidxs[-1]
    hpoterm_end = hpoterm_mention.wordidxs[-1]
    limits = sorted((gene_start, hpoterm_start, gene_end, hpoterm_end))
    start = limits[0]
    betw_start = limits[1]
    betw_end = limits[2]
    # If the gene comes first, we do not prefix, otherwise we do.
    if start == gene_start:
        inv = ""
    else:
        inv = "INV_"
    # The following features are only added if the two mentions are "close
    # enough" to avoid overfitting. The concept of "close enough" is somewhat
    # arbitrary.
    if betw_end - betw_start - 1 < 15:
        # The sequence of lemmas between the two mentions and the sequence of
        # lemmas between the two mentions but using the NERs, if present, and
        # the sequence of POSes between the mentions
        seq_list_ners = []
        seq_list_lemmas = []
        seq_list_poses = []
        for word in sentence.words[betw_start+1:betw_end]:
            if word.ner != "O":
                seq_list_ners.append(word.ner)
            else:
                seq_list_ners.append(word.lemma)
            seq_list_lemmas.append(word.lemma)
            seq_list_poses.append(word.pos)
        seq_ners = " ".join(seq_list_ners)
        seq_lemmas = " ".join(seq_list_lemmas)
        seq_poses = "_".join(seq_list_poses)
        relation.add_feature(inv + "WORD_SEQ_[" + seq_lemmas + "]")
        if seq_ners != seq_lemmas:
            relation.add_feature(inv + "WORD_SEQ_NER_[" + seq_ners + "]")
        relation.add_feature(inv + "POS_SEQ_[" + seq_poses + "]")
    else:
        relation.add_feature(inv + "WORD_SEQ_[TOO_FAR_AWAY]")
        # relation.add_feature(inv + "WORD_SEQ_NER_[TOO_FAR_AWAY]")
        # relation.add_feature(inv + "POS_SEQ_[TOO_FAR_AWAY]")
    # Shortest dependency path between the two mentions
    (dep_path, dep_path_len) = sentence.dep_path(gene_mention, hpoterm_mention)
    if dep_path_len < 10:  # XXX 10 is arbitrary
        relation.add_feature(inv + "DEP_PATH_[" + dep_path + "]")
        (dep_path_pos, dep_path_pos_len) = sentence.dep_path(
            gene_mention, hpoterm_mention, use_pos=True)
        relation.add_feature(inv + "DEP_PATH_POS_[" + dep_path_pos + "]")
    else:
        relation.add_feature(inv + "DEP_PATH_[TOO_FAR_AWAY]")
        # relation.add_feature(inv + "DEP_PATH_POS_[TOO_FAR_AWAY]")

    # For each verb in the sentence compute the dependency path from the
    # mentions to the verb
    for i in range(len(sentence.words)):
        # The filtering of the brackets and commas is from Emily's code.
        if re.search('^VB[A-Z]*$', sentence.words[i].pos) and \
                sentence.words[i].word.isalpha():
                # sentence.words[i].word not in ["{", "}", "(", ")", "[", "]"]
                # and "," not in sentence.words[i].word:
            min_len_g = 10000
            min_path_g = None
            min_path_pos_g = None
            for wordidx in gene_mention.wordidxs:
                (path, length) = sentence.get_word_dep_path(
                    wordidx, sentence.words[i].in_sent_idx)
                if length < min_len_g:
                    min_path_g = path
                    min_len_g = length
                    (min_path_pos_g, l) = sentence.get_word_dep_path(
                        wordidx, sentence.words[i].in_sent_idx, use_pos=True)
            min_len_h = 10000
            min_path_h = None
            min_path_pos_h = None
            for wordidx in hpoterm_mention.wordidxs:
                (path, length) = sentence.get_word_dep_path(
                    wordidx, sentence.words[i].in_sent_idx)
                if length < min_len_h:
                    min_path_h = path
                    min_len_h = length
                    (min_path_pos_h, l) = sentence.get_word_dep_path(
                        wordidx, sentence.words[i].in_sent_idx, use_pos=True)
            if min_len_g < 5 and min_len_h < 5:
                relation.add_feature(
                    inv + "VERB_DEP_PATH_[" + sentence.words[i].lemma + "]_[" +
                    min_path_g + "]_[" + min_path_h + "]")
                relation.add_feature(
                    inv + "VERB_DEP_PATH_POS_[" + sentence.words[i].lemma +
                    "]_[" + min_path_pos_g + "]_[" + min_path_pos_h + "]")


# Add features
def add_features(relation_id, gene_words, pheno_words, sentence):
    # Find the start/end indices of the mentions composing the relation
    gene_start = gene_words[0].in_sent_idx
    pheno_start = pheno_words[0].in_sent_idx
    gene_end = gene_words[-1].in_sent_idx
    pheno_end = pheno_words[-1].in_sent_idx
    limits = sorted((gene_start, pheno_start, gene_end, pheno_end))
    start = limits[0]
    betw_start = limits[1]
    betw_end = limits[2]
    end = limits[3]
    # If the gene comes first, we do not prefix, otherwise we do.
    if start == gene_start:
        inv = ""
    else:
        inv = "INV_"

    # Verbs between the mentions
    verbs_between = []
    minl_gene = 100
    minp_gene = None
    minw_gene = None
    mini_gene = None
    minl_pheno = 100
    # minp_pheno = None
    minw_pheno = None
    mini_pheno = None
    neg_found = False
    # Look all the words, as in the dependency path there could be words that
    # are close to both mentions but not between them
    for i in range(len(sentence.words)):
        # The filtering of the brackets and commas is from Emily's code.
        if re.search('^VB[A-Z]*$', sentence.words[i].pos) and \
                sentence.words[i].word not in ["{", "}", "(", ")", "[", "]"] \
                and "," not in sentence.words[i].word:
            (p_gene, l_gene) = sentence.get_word_dep_path(
                betw_start, sentence.words[i].in_sent_idx)
            (p_pheno, l_pheno) = sentence.get_word_dep_path(
                sentence.words[i].in_sent_idx, betw_end)
            if l_gene < minl_gene:
                minl_gene = l_gene
                minp_gene = p_gene
                minw_gene = sentence.words[i].lemma
                mini_gene = sentence.words[i].in_sent_idx
            if l_pheno < minl_pheno:
                minl_pheno = l_pheno
                #  minp_pheno = p_pheno
                minw_pheno = sentence.words[i].lemma
                mini_pheno = sentence.words[i].in_sent_idx
            # Look for negation.
            if i > 0 and sentence.words[i-1].lemma in \
                    ["no", "not", "neither", "nor"]:
                if i < betw_end - 2:
                    neg_found = True
                    print_feature(
                        relation_id,
                        inv + "NEG_VERB_[" + sentence.words[i-1].word + "]-" +
                        sentence.words[i].lemma)
            else:
                verbs_between.append(sentence.words[i])
    if len(verbs_between) == 1 and not neg_found:
        print_feature(
            sentence.doc_id, relation_id,
            inv + "SINGLE_VERB_[%s]" % verbs_between[0].lemma)
    else:
        for verb in verbs_between:
            if verb.in_sent_idx > betw_start and \
                    verb.in_sent_idx < betw_end:
                print_feature(
                    sentence.doc_id, relation_id,
                    inv + "VERB_[%s]" % verb.lemma)
    if mini_pheno == mini_gene and mini_gene is not None and \
            len(minp_gene) < 50:  # and "," not in minw_gene:
        # feature = inv + 'MIN_VERB_[' + minw_gene + ']' + minp_gene
        # features.append(feature)
        feature = inv + 'MIN_VERB_[' + minw_gene + ']'
        print_feature(sentence.doc_id, relation_id, feature)
    else:
        feature = inv
        if mini_gene is not None:
            # feature = 'MIN_VERB_GENE_[' + minw_gene + ']' + minp_gene
            # print_feature(sentence.doc_id, relation_id, feature)
            feature += 'MIN_VERB_GENE_[' + minw_gene + ']'
        else:
            feature += 'MIN_VERB_GENE_[NULL]'
        if mini_pheno is not None:
            # feature = 'MIN_VERB_pheno_[' + minw_pheno + ']' + minp_pheno)
            # print_feature(sentence.doc_id, relation_id, feature)
            feature += '_pheno_[' + minw_pheno + ']'
        else:
            feature += '_pheno_[NULL]'
        print_feature(sentence.doc_id, relation_id, feature)

    # The following features are only added if the two mentions are "close
    # enough" to avoid overfitting. The concept of "close enough" is somewhat
    # arbitrary.
    neg_word_index = -1
    if betw_end - betw_start - 1 < 8:
        for i in range(betw_start+1, betw_end):
            # Feature for separation between entities.
            # TODO Think about merging these?
            # I think these should be some kind of supervision rule instead?
            if "while" == sentence.words[i].lemma:
                print_feature(sentence.doc_id, relation_id, "SEP_BY_[while]")
            if "whereas" == sentence.words[i].lemma:
                print_feature(sentence.doc_id, relation_id, "SEP_BY_[whereas]")
            if sentence.words[i].lemma in ["no", "not", "neither", "nor"]:
                neg_word_index = i
        # Features for the negative words
        # TODO: We would probably need distant supervision for these
        if neg_word_index > -1:
            gene_p = None
            gene_l = 100
            for word in sentence.words[gene_start:gene_end+1]:
                (p, l) = sentence.get_word_dep_path(
                    word.in_sent_idx, neg_word_index)
                if l < gene_l:
                    gene_p = p
                    gene_l = l
            if gene_p:
                print_feature(
                    sentence.doc_id, relation_id, inv + "NEG_[" + gene_p + "]")
            # pheno_p = None
            # pheno_l = 100
            # for word in sentence.words[pheno_start:pheno_end+1]:
            #    p = sentence.get_word_dep_path(
            #        word.in_sent_idx, neg_word_index)
            #    if len(p) < pheno_l:
            #        pheno_p = p
            #        pheno_l = len(p)
            # if pheno_p:
            #    print_feature(
            #       relation_id, inv + "pheno_TO_NEG_[" + pheno_p + "]")
        # The sequence of lemmas between the two mentions and the sequence of
        # lemmas between the two mentions but using the NERs, if present, and
        # the sequence of POSes between the mentions
        seq_list_ners = []
        seq_list_lemmas = []
        seq_list_poses = []
        for word in sentence.words[betw_start+1:betw_end]:
            if word.ner != "O":
                seq_list_ners.append(word.ner)
            else:
                seq_list_ners.append(word.lemma)
            seq_list_lemmas.append(word.lemma)
            seq_list_poses.append(word.pos)
        seq_ners = " ".join(seq_list_ners)
        seq_lemmas = " ".join(seq_list_lemmas)
        seq_poses = "_".join(seq_list_poses)
        print_feature(
            sentence.doc_id, relation_id,
            inv + "WORD_SEQ_[" + seq_lemmas + "]")
        print_feature(
            sentence.doc_id, relation_id,
            inv + "WORD_SEQ_NER_[" + seq_ners + "]")
        print_feature(
            sentence.doc_id, relation_id, inv + "POS_SEQ_[" + seq_poses + "]")
        # Shortest dependency path between the two mentions
        (path, length) = sentence.dep_path(gene_words, pheno_words)
        print_feature(
            sentence.doc_id, relation_id, inv + "DEP_PATH_[" + path + "]")
    # Number of words between the mentions
    # TODO I think this should be some kind of supervision rule instead?
    # print_feature(sentence.doc_id, relation_id,
    #    inv + "WORD_SEQ_LEN_[" + str(betw_end - betw_start - 1) + "]")
    # 2-gram between the mentions
    if betw_end - betw_start - 1 > 4 and betw_start - betw_end - 1 < 15:
        for i in range(betw_start + 1, betw_end - 1):
            print_feature(
                sentence.doc_id, relation_id,
                "BETW_2_GRAM_[" + sentence.words[i].lemma + "_" +
                sentence.words[i+1].lemma + "]")
    # Lemmas on the exterior of the mentions and on the interior
    feature = inv
    if start > 0:
        feature += "EXT_NGRAM_[" + sentence.words[start - 1].lemma + "]"
    else:
        feature += "EXT_NGRAM_[NULL]"
    if end < len(sentence.words) - 1:
        feature += "_[" + sentence.words[end + 1].lemma + "]"
    else:
        feature += "_[NULL]"
    print_feature(sentence.doc_id, relation_id, feature)
    feature = inv + "INT_NGRAM_[" + sentence.words[betw_start + 1].lemma + \
        "]" + "_[" + sentence.words[betw_end - 1].lemma + "]"
    print_feature(sentence.doc_id, relation_id, feature)


if __name__ == "__main__":
    # Process the input
    with fileinput.input() as input_files:
        for line in input_files:
            # Parse the TSV line
            line_dict = get_dict_from_TSVline(
                line, ["doc_id", "sent_id", "wordidxs", "words", "poses",
                       "ners", "lemmas", "dep_paths", "dep_parents",
                       "relation_id", "gene_wordidxs", "pheno_wordidxs"],
                [no_op, int, lambda x: TSVstring2list(x, int), TSVstring2list,
                    TSVstring2list, TSVstring2list, TSVstring2list,
                    TSVstring2list, lambda x: TSVstring2list(x, int),
                    no_op, lambda x: TSVstring2list(x, int), lambda x:
                    TSVstring2list(x, int)])
            # Create the sentence object
            null_list = [None, ] * len(line_dict["wordidxs"])
            sentence = Sentence(
                line_dict["doc_id"], line_dict["sent_id"],
                line_dict["wordidxs"], line_dict["words"], line_dict["poses"],
                line_dict["ners"], line_dict["lemmas"], line_dict["dep_paths"],
                line_dict["dep_parents"], null_list)
            if sentence.is_weird():
                continue
            gene_words = []
            for gene_wordidx in line_dict["gene_wordidxs"]:
                gene_words.append(sentence.words[gene_wordidx])
            pheno_words = []
            for pheno_wordidx in line_dict["pheno_wordidxs"]:
                pheno_words.append(sentence.words[pheno_wordidx])
            add_features(
                line_dict["relation_id"], gene_words, pheno_words, sentence)
