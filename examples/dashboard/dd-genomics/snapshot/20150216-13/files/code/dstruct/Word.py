#! /usr/bin/env python3
""" A Word class

Originally obtained from the 'pharm' repository, but modified.
"""


class Word(object):

    doc_id = None
    sent_id = None
    in_sent_idx = None
    word = None
    pos = None
    ner = None
    lemma = None
    dep_path = None
    dep_parent = None
    sent_id = None
    box = None

    def __init__(self, _doc_id, _sent_id, _in_sent_idx, _word, _pos, _ner,
                 _lemma, _dep_path, _dep_parent, _box):
        self.doc_id = _doc_id
        self.sent_id = _sent_id
        self.in_sent_idx = _in_sent_idx
        self.word = _word
        self.pos = _pos
        self.ner = _ner
        self.dep_parent = _dep_parent
        self.dep_path = _dep_path
        self.box = _box
        self.lemma = _lemma
        # If do not do the following, outputting an Array in the language will
        # crash
        # XXX (Matteo) This was in the pharm code, not sure what it means
        # I actually don't think this should go here.
        # self.lemma = self.lemma.replace('"', "''")
        # self.lemma = self.lemma.replace('\\', "_")

    def __repr__(self):
        return self.word

    # Return the NER tag if different than 'O', otherwise return the lemma
    def get_feature(self, use_pos=False):
        if use_pos:
            return self.pos
        elif self.ner == 'O':
            return self.lemma
        else:
            return self.ner
