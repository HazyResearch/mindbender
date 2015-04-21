#! /usr/bin/env python3
#
# Look for acronyms defined in a document that look like gene symbols

import fileinput
from dstruct.Sentence import Sentence
from helper.dictionaries import load_dict
from helper.easierlife import get_dict_from_TSVline, list2TSVarray, no_op, \
    TSVstring2list


# Return acronyms from sentence
def extract(sentence):
    acronyms = []
    # First method: Look for a sentence that starts with "Abbreviations"
    if len(sentence.words) > 2 and \
            sentence.words[0].word.casefold() == "abbreviations" and \
            (sentence.words[1].word.casefold() == ":" or 
                    sentence.words[1].word.casefold() == "used"):
        words = [x.word for x in sentence.words]
        index = 2
        while index < len(words):
            acronym = dict()
            acronym["acronym"] = words[index]
            # There are a lot of typos and different separators used in the
            # text, this is obviously a best effort ...
            try:
                comma_index = words.index(",", index + 1)
            except:
                comma_index = len(words)
            try:
                semicolon_index = words.index(";", index + 1)
            except:
                semicolon_index = len(words)
            try:
                colon_index = words.index(":", index + 1)
            except:
                colon_index = len(words)
            definition_start = min(
                [comma_index, semicolon_index, colon_index]) + 1
            if definition_start > len(words):
                definition_start = index + 1
            try:
                definition_end = words.index(";", definition_start + 1)
            except:
                if words[-1] == ".":
                    definition_end = len(words) - 1
                else:
                    definition_end = len(words)
            definition = " ".join(words[definition_start:definition_end])
            if words[index] not in merged_genes_dict or \
                    words[index] in inverted_long_names:
                index = definition_end + 1
                continue
            # If we didn't find a definition, give up
            if definition.strip() == "":
                index = definition_end + 1
                continue
            acronym["doc_id"] = sentence.doc_id
            acronym["sent_id"] = sentence.sent_id
            acronym["word_idx"] = sentence.words[index].in_sent_idx
            acronym["definition"] = definition
            acronyms.append(acronym)
            index = definition_end + 1
    else:
        # Second method: find 'A Better Example (ABE)' type of definitions.
        # Skip first and last word of sentence, to allow for "(" and ")".
        for word in sentence.words[1:-1]:
            acronym = None
            # Look for definition only if 
            # - this word is in the genes dictionary AND
            # - is uppercase AND
            # - it only contains letters AND
            # - it has length at least 2  AND
            # - it comes between "(" and ")" or "(" and ";" # or "(" # and "," 
            if word.word in merged_genes_dict and \
                    word.word not in inverted_long_names and \
                    word.word.isupper() and word.word.isalpha() and \
                    len(word.word) >= 2 and \
                    ((sentence.words[word.in_sent_idx - 1].word == "(" and
                      sentence.words[word.in_sent_idx + 1].word in [
                      ")", ";" ",", "]"]) or
                     (sentence.words[word.in_sent_idx - 1].word == "[" and
                      sentence.words[word.in_sent_idx + 1].word == "]")):
                word_idx = word.in_sent_idx
                window_size = len(word.word)
                # Look for a sequence of words coming before this one whose
                # initials would create this acronym
                start_idx = 0
                while start_idx + window_size - 1 < word_idx:
                    window_words = sentence.words[start_idx:(start_idx +
                                                             window_size)]
                    is_definition = True
                    for window_index in range(window_size):
                        if window_words[window_index].word[0].lower() != \
                                word.word[window_index].lower():
                            is_definition = False
                            break
                    definition = " ".join([w.word for w in window_words])
                    # Only consider this acronym if the definition is valid
                    if is_definition:
                        acronym = dict()
                        acronym["acronym"] = word.word
                        acronym["definition"] = definition
                        acronyms.append(acronym)
                        break
                    start_idx += 1
    return acronyms


# Load the genes dictionary
merged_genes_dict = load_dict("merged_genes")
inverted_long_names = load_dict("inverted_long_names")

if __name__ == "__main__":
    # Process the input
    with fileinput.input() as input_files:
        for line in input_files:
            # Parse the TSV line
            line_dict = get_dict_from_TSVline(
                line,
                ["doc_id", "sent_ids", "wordidxss", "wordss", "posess", 
                    "nerss", "lemmass", "dep_pathss", "dep_parentss",
                    "bounding_boxess"],
                [no_op, lambda x: TSVstring2list(x, int), 
                    lambda x: TSVstring2list(x,sep='!~!'), 
                    lambda x: TSVstring2list(x,sep='!~!'), 
                    lambda x: TSVstring2list(x,sep='!~!'),
                    lambda x: TSVstring2list(x,sep='!~!'),
                    lambda x: TSVstring2list(x,sep='!~!'), 
                    lambda x: TSVstring2list(x,sep='!~!'),
                    lambda x: TSVstring2list(x,sep='!~!'),
                    lambda x: TSVstring2list(x,sep='!~!')])
            # Acronyms defined in the document
            acronyms = dict()
            for idx in range(len(line_dict["sent_ids"])):
                wordidxs = TSVstring2list(line_dict["wordidxss"][idx], int)
                words = TSVstring2list(line_dict["wordss"][idx])
                poses = TSVstring2list(line_dict["posess"][idx])
                ners = TSVstring2list(line_dict["nerss"][idx])
                lemmas = TSVstring2list(line_dict["lemmass"][idx])
                dep_paths = TSVstring2list(line_dict["dep_pathss"][idx])
                dep_parents = TSVstring2list(line_dict["dep_parentss"][idx],
                        int)
                bounding_boxes = TSVstring2list(line_dict["bounding_boxess"][idx])
                # Create the Sentence object
                sentence = Sentence(
                    line_dict["doc_id"], line_dict["sent_ids"][idx], wordidxs,
                    words, poses, ners, lemmas, dep_paths, dep_parents,
                    bounding_boxes)
                # Extract the acronyms from the sentence
                sen_acronyms = extract(sentence)
                for acronym in sen_acronyms:
                    if acronym["acronym"] not in acronyms:
                        acronyms[acronym["acronym"]] = set()
                    acronyms[acronym["acronym"]].add(acronym["definition"])
            # Classify the acronyms
            for acronym in acronyms:
                contains_kw = False
                is_correct = None
                for definition in acronyms[acronym]:
                    # If the definition is in the gene dictionary, supervise as
                    # correct
                    if definition in merged_genes_dict:
                        is_correct = True
                        break
                    else:
                        # Check if the definition contains some keywords that
                        # make us suspect that it is probably a gene/protein.
                        # This list is incomplete, and it would be good to add
                        # to it.
                        if contains_kw:
                            continue
                        for word in definition.split():
                            if word.endswith("ase") and len(word) > 5:
                                contains_kw = True
                                break
                        if " gene" in definition or \
                                "protein" in definition or \
                                "factor" in definition or \
                                "ligand" in definition or \
                                "enzyme" in definition or \
                                "receptor" in definition or \
                                "pseudogene" in definition:
                            contains_kw = True
                # If no significant keyword in any definition, supervise as not
                # correct
                if not contains_kw and not is_correct:
                    is_correct = False
                is_correct_str = "\\N"
                if is_correct is not None:
                    is_correct_str = is_correct.__repr__()
                print("\t".join(
                    (line_dict["doc_id"], acronym,
                    list2TSVarray(list(acronyms[acronym]), quote=True),
                    is_correct_str)))

