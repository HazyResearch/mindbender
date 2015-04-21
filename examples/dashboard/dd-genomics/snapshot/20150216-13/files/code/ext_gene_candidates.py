#! /usr/bin/env python3
#
# Extract gene mention candidates and perform distant supervision
#

import fileinput

from dstruct.Mention import Mention
from dstruct.Sentence import Sentence
from helper.dictionaries import load_dict
from helper.easierlife import get_all_phrases_in_sentence, \
    get_dict_from_TSVline, TSVstring2list, no_op

DOC_ELEMENTS = frozenset(
    ["figure", "table", "figures", "tables", "fig", "fig.", "figs", "figs.",
     "file", "movie"])

INDIVIDUALS = frozenset(["individual", "individuals", "patient"])

TYPES = frozenset(["group", "type", "class", "method"])

# Load the dictionaries that we need
merged_genes_dict = load_dict("merged_genes")
inverted_long_names = load_dict("inverted_long_names")
hpoterms_with_gene = load_dict("hpoterms_with_gene")
english_dict = load_dict("english")

# Max mention length. We won't look at subsentences longer than this.
max_mention_length = 0
for key in merged_genes_dict:
    length = len(key.split())
    if length > max_mention_length:
        max_mention_length = length
# doubling to take into account commas and who knows what
max_mention_length *= 2


# Supervise the candidates.
def supervise(mentions, sentence):
    phrase = " ".join([x.word for x in sentence.words])
    new_mentions = []
    for mention in mentions:
        new_mentions.append(mention)
        if mention.is_correct is not None:
            continue
        # The candidate is a long name.
        if " ".join([word.word for word in mention.words]) in \
                inverted_long_names:
            mention.is_correct = True
            mention.type = "GENE_SUP_long"
            continue
        # The candidate is a MIM entry
        if mention.words[0].word == "MIM":
            mention_word_idx = mention.words[0].in_sent_idx
            if mention_word_idx < len(sentence.words) - 1:
                next_word = sentence.words[mention_word_idx + 1].word
                if next_word.casefold() in ["no", "no.", "#", ":"] and \
                        mention_word_idx + 2 < len(sentence.words):
                    next_word = sentence.words[mention_word_idx + 2].word
                try:
                    int(next_word)
                    mention.is_correct = False
                    mention.type = "GENE_SUP_MIM"
                    continue
                except ValueError:
                    pass
        # The candidate is an entry in Gene Ontology
        if len(mention.words) == 1 and mention.words[0].word == "GO":
            try:
                if sentence.words[mention.words[0].in_sent_idx + 1][0] == ":":
                    mention.is_correct = False
                    mention.type = "GENE_SUP_go"
            except:
                pass
            continue
        # The phrase starts with words that are indicative of the candidate not
        # being a mention of a gene
        # We add a feature for this, as it is a context property
        if phrase.startswith("Performed the experiments :") or \
                phrase.startswith("Wrote the paper :") or \
                phrase.startswith("W'rote the paper :") or \
                phrase.startswith("Wlrote the paper") or \
                phrase.startswith("Contributed reagents") or \
                phrase.startswith("Analyzed the data :") or \
                phrase.casefold().startswith("address"):
            # An unsupervised copy with the special feature
            # unsuper_enriched = Mention(
            #    "GENE_dontsup", mention.entity, mention.words)
            # unsuper_enriched.features = mention.features.copy()
            # unsuper_enriched.add_feature("IN_CONTRIB_PHRASE")
            # new_mentions.append(unsuper_enriched)
            # This candidate contain only the 'special' feature.
            # super_spec = Mention(
            #    "GENE_SUP_contr_2", mention.entity, mention.words)
            # super_spec.is_correct = False
            # super_spec.add_feature("IN_CONTRIB_PHRASE")
            # new_mentions.append(super_spec)
            # Set is_correct and type.
            mention.is_correct = False
            mention.type = "GENE_SUP_contr_1"
            continue
        # Index of the word on the left
        idx = mention.wordidxs[0] - 1
        if idx >= 0:
            # The candidate is preceded by a "%" (it's probably a quantity)
            if sentence.words[idx].word == "%":
                mention.is_correct = False
                mention.type = "GENE_SUP_%"
                continue
            # The candidate comes after a "document element" (e.g., table, or
            # figure)
            if sentence.words[idx].word.casefold() in DOC_ELEMENTS:
                mention.is_correct = False
                mention.type = "GENE_SUP_doc"
                continue
            # The candidate comes after an "individual" word (e.g.,
            # "individual")
            if sentence.words[idx].word.casefold() in INDIVIDUALS and \
                    not mention.words[0].word.isalpha() and \
                    not len(mention.words[0].word) > 4:
                mention.is_correct = False
                mention.type = "GENE_SUP_indiv"
                continue
            # The candidate comes after a "type" word, and it is made only of
            # the letters "I" and "V"
            if sentence.words[idx].lemma.casefold() in TYPES and \
                    set(mention.words[0].word).issubset(set(["I", "V"])):
                mention.is_correct = False
                mention.type = "GENE_SUP_type"
                continue
        # Index of the word on the right
        idx = mention.wordidxs[-1] + 1
        if idx < len(sentence.words):
            # The candidate is followed by a "=" (it's probably a quantity)
            if sentence.words[idx].word == "=":
                mention.is_correct = False
                mention.type = "GENE_SUP_="
                continue
            # The candidate is followed by a ":" and the word after it is a
            # number (it's probably a quantity)
            if sentence.words[idx].word == ":":
                try:
                    float(sentence.words[idx + 1].word)
                    mention.is_correct = False
                    mention.type = "GENE_SUP_:"
                except:  # both ValueError and IndexError
                    pass
                continue
            # The candidate comes before "et"
            if sentence.words[idx].word == "et":
                mention.is_correct = False
                mention.type = "GENE_SUP_et"
                continue
        # The candidate is a DNA triplet
        # We check this by looking at whether the word before or after is also
        # a DNA triplet.
        if len(mention.words) == 1 and len(mention.words[0].word) == 3 and \
                set(mention.words[0].word) <= set("ACGT"):
            done = False
            idx = mention.wordidxs[0] - 1
            if idx > 0:
                if set(sentence.words[idx].word) <= set("ACGT"):
                    mention.is_correct = False
                    mention.type = "GENE_SUP_dna"
                    continue
            idx = mention.wordidxs[-1] + 1
            if not done and idx < len(sentence.words):
                if set(sentence.words[idx].word) <= set("ACGT"):
                    mention.is_correct = False
                    mention.type = "GENE_SUP_dna"
                    continue
        # If it's "II", it's most probably wrong.
        if mention.words[0].word == "II":
            mention.is_correct = False
            mention.type = "GENE_SUP_ii"
            continue
        # The candidate comes after an organization, or a location, or a
        # person. We skip commas as they may trick us.
        comes_after = None
        loc_idx = mention.wordidxs[0] - 1
        while loc_idx >= 0 and sentence.words[loc_idx].lemma == ",":
            loc_idx -= 1
        if loc_idx >= 0 and \
                sentence.words[loc_idx].ner in \
                ["ORGANIZATION", "LOCATION", "PERSON"] and \
                sentence.words[loc_idx].word not in merged_genes_dict:
            comes_after = sentence.words[loc_idx].ner
        # The candidate comes before an organization, or a location, or a
        # person. We skip commas, as they may trick us.
        comes_before = None
        loc_idx = mention.wordidxs[-1] + 1
        while loc_idx < len(sentence.words) and \
                sentence.words[loc_idx].lemma == ",":
            loc_idx += 1
        if loc_idx < len(sentence.words) and sentence.words[loc_idx].ner in \
                ["ORGANIZATION", "LOCATION", "PERSON"] and \
                sentence.words[loc_idx].word not in merged_genes_dict:
            comes_before = sentence.words[loc_idx].ner
        # Not correct if it's most probably a person name.
        if comes_before and comes_after:
            mention.is_correct = False
            mention.type = "GENE_SUP_name"
            continue
        # Comes after person and before "," or ":", so it's probably a person
        # name
        if comes_after == "PERSON" and \
                mention.words[-1].in_sent_idx + 1 < len(sentence.words) and \
                sentence.words[mention.words[-1].in_sent_idx + 1].word \
                in [",", ":"]:
            mention.is_correct = False
            mention.type = "GENE_SUP_name2"
            continue
        if comes_after == "PERSON" and mention.words[0].ner == "PERSON":
            mention.is_correct = False
            mention.type = "GENE_SUP_name3"
            continue
        # Is a location and comes before a location so it's probably wrong
        if comes_before == "LOCATION" and mention.words[0].ner == "LOCATION":
            mention.is_correct = False
            mention.type = "GENE_SUP_loc"
            continue
    return new_mentions


# Return a list of mention candidates extracted from the sentence
def extract(sentence):
    mentions = []
    # Skip the sentence if there are no English words in the sentence
    no_english_words = True
    for word in sentence.words:
        if len(word.word) > 2 and \
                (word.word in english_dict or
                 word.word.casefold() in english_dict):
            no_english_words = False
            break
    if no_english_words:
        return []  # Stop iteration

    sentence_is_upper = False
    if " ".join([x.word for x in sentence.words]).isupper():
        sentence_is_upper = True
    # The following set keeps a list of indexes we already looked at and which
    # contained a mention
    history = set()
    words = sentence.words
    # Scan all subsequences of the sentence of length up to max_mention_length
    for start, end in get_all_phrases_in_sentence(sentence,
                                                  max_mention_length):
        if start in history or end in history:
                continue
        phrase = " ".join([word.word for word in words[start:end]])
        if sentence_is_upper:  # XXX This may not be a great idea...
            phrase = phrase.casefold()
        mention = None
        # If the phrase is a hpoterm name containing a gene, then it is a
        # mention candidate to supervise as negative
        if phrase in hpoterms_with_gene:
            mention = Mention("GENE_SUP_HPO", phrase, words[start:end])
            mention.is_correct = False
            mentions.append(mention)
            for i in range(start, end):
                history.add(i)
        # If the phrase is in the gene dictionary, then is a mention candidate
        if len(phrase) > 1 and phrase in merged_genes_dict:
            # The entity is a list of all the main symbols that could have the
            # phrase as symbol. They're separated by "|".
            mention = Mention("GENE",
                              "|".join(merged_genes_dict[phrase]),
                              words[start:end])
            # Add mention to the list
            mentions.append(mention)
            # Add indexes to history so that they are not used for another
            # mention
            for i in range(start, end):
                history.add(i)
    return mentions


if __name__ == "__main__":
    # Process the input
    with fileinput.input() as input_files:
        for line in input_files:
            # Parse the TSV line
            line_dict = get_dict_from_TSVline(
                line,
                ["doc_id", "sent_id", "wordidxs", "words", "poses", "ners",
                    "lemmas"],
                [no_op, int, lambda x: TSVstring2list(x, int), TSVstring2list,
                    TSVstring2list, TSVstring2list, TSVstring2list])
            # Create the sentence object
            null_list = [None, ] * len(line_dict["wordidxs"])
            sentence = Sentence(
                line_dict["doc_id"], line_dict["sent_id"],
                line_dict["wordidxs"], line_dict["words"], line_dict["poses"],
                line_dict["ners"], line_dict["lemmas"], null_list, null_list,
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
