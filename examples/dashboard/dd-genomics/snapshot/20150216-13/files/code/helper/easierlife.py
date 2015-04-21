#! /usr/bin/env python3
""" Helper functions to make our life easier.

Originally obtained from the 'pharm' repository, but modified.
"""

import fileinput
import json
import os.path
import sys

from dstruct.Sentence import Sentence

# BASE_DIR denotes the application directory
BASE_DIR, throwaway = os.path.split(os.path.realpath(__file__))
BASE_DIR = os.path.realpath(BASE_DIR + "/../..")


# Return the start and end indexes of all subsets of words in the sentence
# sent, with size at most max_phrase_length
def get_all_phrases_in_sentence(sent, max_phrase_length):
    for start in range(len(sent.words)):
        for end in reversed(range(start + 1, min(
                            len(sent.words), start + 1 + max_phrase_length))):
            yield (start, end)


# Return Sentence objects from input lines
def get_input_sentences(input_files=sys.argv[1:]):
    with fileinput.input(files=input_files) as f:
        for line in f:
            sent_dict = json.loads(line)
            yield Sentence(
                sent_dict["doc_id"], sent_dict["sent_id"],
                sent_dict["wordidxs"], sent_dict["words"], sent_dict["poses"],
                sent_dict["ners"], sent_dict["lemmas"], sent_dict["dep_paths"],
                sent_dict["dep_parents"], sent_dict["bounding_boxes"])


# Given a TSV line, a list of keys, and a list of functions, return a dict
# like the one returned by json.loads()
def get_dict_from_TSVline(line, keys, funcs):
    assert len(keys) == len(funcs)
    line_dict = dict()
    while line[-1] == '\n':
        line = line[:-1]
    tokens = line.split("\t")
    assert len(tokens) == len(keys)
    for i in range(len(tokens)):
        token = tokens[i]
        # skip the token if it's NULL
        if token != "":
            try:
                line_dict[keys[i]] = funcs[i](token)
            except:
                pass
    return line_dict


# Return the argument
def no_op(x):
    return x


# Transform a TSV string into a boolean
def TSVstring2bool(string):
    if string == "t":
        return True
    elif string == "f":
        return False
    else:
        return None


# Transform a string obtained by postgresql array_str() into a list.
# The parameter func() gets applied to the elements of the list
def TSVstring2list(string, func=(lambda x: x), sep="|^|"):
    tokens = string.split(sep)
    return [func(x) for x in tokens]


# Transform a string obtained by postgresql into a dictionary whose keys are in
# the form "TSV_X" where X is an integer from 0. Each value of the dict is a
# list obtained using TSVstring2list.
def TSVstring2dict(string, func=(lambda x: x), sep="|^^"):
    tsv_dict = dict()
    i = 0
    tokens = string.split(sep)
    for token in tokens:
        tsv_dict["TSV_" + str(i)] = TSVstring2list(token)
        i += 1
    return tsv_dict


# Convert a list to a string that can be used in a TSV column and intepreted as
# an array by the PostreSQL COPY FROM command.
# If 'quote' is True, then double quote the string representation of the
# elements of the list, and escape double quotes and backslashes.
def list2TSVarray(a_list, quote=False):
    if quote:
        for index in range(len(a_list)):
            if "\\" in str(a_list[index]):
                # Replace '\' with '\\\\"' to be accepted by COPY FROM
                a_list[index] = str(a_list[index]).replace("\\", "\\\\\\\\")
            # This must happen the previous substitution
            if "\"" in str(a_list[index]):
                # Replace '"' with '\\"' to be accepted by COPY FROM
                a_list[index] = str(a_list[index]).replace("\"", "\\\\\"")
        string = ",".join(list(map(lambda x: "\"" + str(x) + "\"", a_list)))
    else:
        string = ",".join(list(map(lambda x: str(x), a_list)))
    return "{" + string + "}"


def print_feature(doc_id, mention_id, feature):
    if "\\" in feature:
        # Replace '\' with '\\\\"' to be accepted by COPY FROM
        feature = feature.replace("\\", "\\\\\\\\")
    # This must happen the previous substitution
    if "\"" in feature:
        # Replace '"' with '\\"' to be accepted by COPY FROM
        feature = feature.replace("\"", "\\\\\"")
    print(doc_id + "\t" + mention_id + "\t\"" + feature + "\"")
