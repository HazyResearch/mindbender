#! /usr/bin/env python3
""" An object representing a relation

"""

import json

from helper.easierlife import list2TSVarray


class Relation(object):
    doc_id = None
    sent_id_1 = None
    sent_id_2 = None
    type = None
    mention_1_id = None
    mention_2_id = None
    mention_1_words = None
    mention_2_words = None
    is_correct = None

    def __init__(self, _type, mention_1, mention_2):
        self.doc_id = mention_1.words[0].doc_id
        self.sent_id_1 = mention_1.words[0].sent_id
        self.sent_id_2 = mention_2.words[0].sent_id
        self.mention_1_id = mention_1.id()
        self.mention_2_id = mention_2.id()
        self.type = _type
        self.mention_1_words = mention_1.words
        self.mention_2_words = mention_2.words

    def id(self):
        return "RELATION_{}_{}_{}_{}_{}_{}_{}_{}".format(
            self.type, self.doc_id, self.sent_id_1, self.sent_id_2,
            self.mention_1_words[0].in_sent_idx,
            self.mention_1_words[-1].in_sent_idx,
            self.mention_2_words[0].in_sent_idx,
            self.mention_2_words[-1].in_sent_idx)

    def json_dump(self):
        return json.dumps(
            {"id": None, "doc_id": self.doc_id, "sent_id_1": self.sent_id_1,
                "sent_id_2": self.sent_id_2, "relation_id": self.id(),
                "type": self.type, "mention_id_1": self.mention_1_id,
                "mention_id_2": self.mention_2_id,
                "wordidxs_1": [x.in_sent_idx for x in self.mention_1_words],
                "wordidxs_2": [x.in_sent_idx for x in self.mention_2_words],
                "words_1": [x.word for x in self.mention_1_words],
                "words_2": [x.word for x in self.mention_2_words],
                "is_correct": self.is_correct})

    def tsv_dump(self):
        is_correct_str = "\\N"
        if self.is_correct is not None:
            is_correct_str = self.is_correct.__repr__()
        return "\t".join(
            ["\\N", self.doc_id, str(self.sent_id_1), str(self.sent_id_2),
                self.id(), self.type, self.mention_1_id, self.mention_2_id,
                list2TSVarray([x.in_sent_idx for x in self.mention_1_words]),
                list2TSVarray([x.in_sent_idx for x in self.mention_2_words]),
                list2TSVarray([x.word for x in self.mention_1_words], True),
                list2TSVarray([x.word for x in self.mention_2_words], True),
                is_correct_str])
