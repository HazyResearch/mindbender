#! /usr/bin/env pypy

from lib import dd as ddlib
import re
import sys
import json

def load_dict (dict_intervals):
    for l in open(ddlib.BASE_FOLDER + '/dicts/intervals.tsv', 'r'):
        (begin, end, name) = l.rstrip().split('\t')
        if name.startswith('Cryptic'): continue
        dict_intervals[name.lower()] = name + '|' + begin + '|' + end
        va = name.lower().replace('late ', 'upper ').replace('early ', 'lower')
        if va != name.lower():
            dict_intervals[va] = name + '|' + begin + '|' + end	

def main (words, all_phrases):
    dict_intervals = {}
    load_dict (dict_intervals)

    history = {}
    for (start, end) in all_phrases:
        if start in history or end in history: continue
        phrase = " ".join(words[start:end])

        if phrase.lower() in dict_intervals:
            name = dict_intervals[phrase.lower()]
            yield {"start": start, "end":end, "type": "INTERVAL", "entity": name, "is_correct": None}
            for i in range(start, end):
                history[i]=1

        if '-' in phrase:
            i = -1
            for part in phrase.split('-'):
                i = i + 1
                if part.lower() in dict_intervals:
                    name = dict_intervals[part.lower()]
                    yield {"start": start, "end":end, "type": "INTERVAL", "entity": name, "is_correct": None}
                    for i in range(start, end):
                        history[i]=1
