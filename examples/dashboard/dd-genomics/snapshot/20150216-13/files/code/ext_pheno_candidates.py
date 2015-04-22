#! /usr/bin/env python3

import fileinput
import random
import re

from nltk.stem.snowball import SnowballStemmer

from dstruct.Mention import Mention
from dstruct.Sentence import Sentence
from helper.easierlife import get_all_phrases_in_sentence, \
    get_dict_from_TSVline, TSVstring2list, no_op
from helper.dictionaries import load_dict

max_mention_length = 8  # This is somewhat arbitrary

NEG_PROB = 0.005  # Probability of generating a random negative mention


# Load the dictionaries that we need
english_dict = load_dict("english")
stopwords_dict = load_dict("stopwords")
inverted_hpoterms = load_dict("hpoterms_inverted")
hponames_to_ids = load_dict("hponames_to_ids")
genes_with_hpoterm = load_dict("genes_with_hpoterm")
# hpodag = load_dict("hpoparents")


stems = set()
for hpo_name in inverted_hpoterms:
    stem_set = inverted_hpoterms[hpo_name]
    stems |= stem_set
stems = frozenset(stems)

# The keys of the following dictionary are sets of stems, and the values are
# sets of hpoterms whose name, without stopwords, gives origin to the
# corresponding set of stems (as key)
hpoterms_dict = load_dict("hpoterms")

# Initialize the stemmer
stemmer = SnowballStemmer("english")


# Perform the supervision
def supervise(mentions, sentence):
    for mention in mentions:
        # Skip if we already supervised it (e.g., random mentions or
        # gene long names)
        if mention.is_correct is not None:
            continue
        # The next word is 'gene' or 'protein', so it's actually a gene
        if mention.words[-1].in_sent_idx < len(sentence.words) - 1:
            next_word = sentence.words[mention.words[-1].in_sent_idx + 1].word
            if next_word.casefold() in ["gene", "protein"]:
                mention.is_correct = False
                mention.type = "PHENO_SUP_GENE"
                continue
        mention_lemmas = set([x.lemma.casefold() for x in mention.words])
        name_words = set([x.casefold() for x in
                          mention.entity.split("|")[1].split()])
        # The mention is exactly the HPO name
        if mention_lemmas == name_words and \
                mention.words[0].lemma != "pneunomiae":
            mention.is_correct = True
            mention.type = "PHENO_SUP_FULL"
    return mentions


# Return a list of mention candidates extracted from the sentence
def extract(sentence):
    mentions = []
    mention_ids = set()
    # If there are no English words in the sentence, we skip it.
    no_english_words = True
    for word in sentence.words:
        word.stem = stemmer.stem(word.word)  # Here so all words have stem
        if len(word.word) > 2 and \
                (word.word in english_dict or
                 word.word.casefold() in english_dict):
            no_english_words = False
    if no_english_words:
        return mentions
    history = set()
    # Iterate over each phrase of length at most max_mention_length
    for start, end in get_all_phrases_in_sentence(sentence,
                                                  max_mention_length):
        if start in history or end - 1 in history:
            continue
        phrase = " ".join([word.word for word in sentence.words[start:end]])
        # If the phrase is a gene long name containing a phenotype name, create
        # a candidate that we supervise as negative
        if len(phrase) > 1 and phrase in genes_with_hpoterm:
            mention = Mention("HPOTERM_SUP_GENEL",
                              phrase,
                              sentence.words[start:end])
            mention.is_correct = False
            mentions.append(mention)
            for word in sentence.words[start:end]:
                history.add(word.in_sent_idx)
            continue
    # Iterate over each phrase of length at most max_mention_length
    for start, end in get_all_phrases_in_sentence(sentence,
                                                  max_mention_length):
        should_continue = False
        for i in range(start, end):
            if i in history:
                should_continue = True
                break
        if should_continue:
            continue
        phrase = " ".join([word.word for word in sentence.words[start:end]])
        # The list of stems in the phrase (not from stopwords or symbols, and
        # not already used for a mention)
        phrase_stems = []
        for word in sentence.words[start:end]:
            if not re.match("^(_|\W)+$", word.word) and \
                    (len(word.word) == 1 or
                     word.lemma.casefold() not in stopwords_dict):
                phrase_stems.append(word.stem)
        phrase_stems_set = frozenset(phrase_stems)
        if phrase_stems_set in hpoterms_dict:
            # Find the word objects of that match
            mention_words = []
            mention_lemmas = []
            mention_stems = []
            for word in sentence.words[start:end]:
                if word.stem in phrase_stems_set and \
                        word.lemma.casefold() not in mention_lemmas and \
                        word.stem not in mention_stems:
                    mention_lemmas.append(word.lemma.casefold())
                    mention_words.append(word)
                    mention_stems.append(word.stem)
                    if len(mention_words) == len(phrase_stems_set):
                        break
            entity = list(hpoterms_dict[phrase_stems_set])[0]
            mention = Mention(
                "PHENO", hponames_to_ids[entity] + "|" + entity,
                mention_words)
            # The following is a way to avoid duplicates.
            # It's ugly and not perfect
            if mention.id() in mention_ids:
                continue
            mention_ids.add(mention.id())
            mentions.append(mention)
            for word in mention_words:
                history.add(word.in_sent_idx)
    # Generate some negative candidates at random, if this sentences didn't
    # contain any other candidate. We want the candidates to be nouns.
    if len(mentions) == 0 and random.random() <= NEG_PROB:
        index = random.randint(0, len(sentence.words) - 1)
        # We may not get a noun at random, so we try again if we don't.
        tries = 10
        while not sentence.words[index].pos.startswith("NN") and tries > 0:
            index = random.randint(0, len(sentence.words) - 1)
            tries -= 1
        if sentence.words[index].pos.startswith("NN"):
            mention = Mention(
                "PHENO_SUP_rand", sentence.words[index].lemma.casefold(),
                sentence.words[index:index+1])
            mention.is_correct = False
            mentions.append(mention)
    return mentions


if __name__ == "__main__":
    # Process the input
    with fileinput.input() as input_files:
        for line in input_files:
            # Parse the TSV line
            line_dict = get_dict_from_TSVline(
                line,
                ["doc_id", "sent_id", "wordidxs", "words", "poses", "lemmas"],
                [no_op, int, lambda x: TSVstring2list(x, int), TSVstring2list,
                    TSVstring2list, TSVstring2list])
            # Create the sentence object
            null_list = [None, ] * len(line_dict["wordidxs"])
            sentence = Sentence(
                line_dict["doc_id"], line_dict["sent_id"],
                line_dict["wordidxs"], line_dict["words"], line_dict["poses"],
                null_list, line_dict["lemmas"], null_list, null_list,
                null_list)
            # Skip weird sentences
            if sentence.is_weird():
                continue
            # Get list of mentions candidates in this sentence
            mentions = extract(sentence)
            # Supervise them
            new_mentions = supervise(mentions, sentence)
            # Print!
            for mention in new_mentions:
                print(mention.tsv_dump())
