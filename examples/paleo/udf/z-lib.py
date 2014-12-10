#! /usr/bin/env python3

# import fileinput
# import json
# import os.path
# import sys

# BASE_DIR, throwaway = os.path.split(os.path.realpath(__file__))
# BASE_DIR = os.path.realpath(BASE_DIR + "/../..")

### from </helper/easierlife.py> (in memex)
def get_all_phrases_in_sentence (words, max_phrase_length):
    for start in range(len(words)):
        for end in reversed(range(start + 1, min(len(words), start + 1 + max_phrase_length))):
            yield (start, end)
