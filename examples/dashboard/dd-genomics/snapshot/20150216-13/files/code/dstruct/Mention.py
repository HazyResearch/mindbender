#! /usr/bin/env python3
""" A generic Mention class

Originally obtained from the 'pharm' repository, but modified.
"""

import json

from helper.easierlife import list2TSVarray


class Mention(object):

    doc_id = None
    sent_id = None
    wordidxs = None
    type = None
    entity = None
    words = None
    is_correct = None
    right_lemma = ""
    left_lemma = ""

    def __init__(self, _type, _entity, _words):
        self.doc_id = _words[0].doc_id
        self.sent_id = _words[0].sent_id
        self.wordidxs = sorted([word.in_sent_idx for word in _words])
        self.type = _type
        self.entity = _entity
        # These are Word objects
        self.words = _words
        self.is_correct = None

    def __repr__(self):
        return " ".join([w.word for w in self.words])

    def id(self):
        return "MENTION_{}_{}_{}_{}_{}".format(
            self.type, self.doc_id, self.sent_id, self.wordidxs[0],
            self.wordidxs[-1])

    # Dump self to a json object
    def json_dump(self):
        json_obj = {"id": None, "doc_id": self.doc_id, "sent_id": self.sent_id,
                    "wordidxs": self.wordidxs, "mention_id": self.id(), "type":
                    self.type, "entity": self.entity,
                    "words": [w.word for w in self.words],
                    "is_correct": self.is_correct}
        return json.dumps(json_obj)

    # Dump self to a TSV line
    def tsv_dump(self):
        is_correct_str = "\\N"
        if self.is_correct is not None:
            is_correct_str = self.is_correct.__repr__()
        tsv_line = "\t".join(
            ["\\N", self.doc_id, str(self.sent_id),
                list2TSVarray(self.wordidxs), self.id(), self.type,
                self.entity, list2TSVarray(self.words, quote=True),
                is_correct_str])
        return tsv_line
