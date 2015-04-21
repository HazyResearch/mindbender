#! /usr/bin/env python3
""" A Sentence class

Basically a container for an array of Word objects, plus doc_id and sent_id.

Originally obtained from the 'pharm' repository, but modified.
"""

from dstruct.Word import Word


class Sentence(object):
    # to avoid bad parse tree that have self-recursion
    _MAX_DEP_PATH_LEN = 1000
    doc_id = None
    sent_id = None
    words = []

    def __init__(self, _doc_id, _sent_id, _wordidxs, _words, _poses, _ners,
                 _lemmas, _dep_paths, _dep_parents, _bounding_boxes):
        self.doc_id = _doc_id
        self.sent_id = _sent_id
        wordidxs = _wordidxs
        words = _words
        poses = _poses
        ners = _ners
        lemmas = _lemmas
        dep_paths = _dep_paths
        dep_parents = _dep_parents
        bounding_boxes = _bounding_boxes
        self.words = []
        if _wordidxs:  # checking for None
            for i in range(len(wordidxs)):
                word = Word(self.doc_id, self.sent_id, wordidxs[i], words[i],
                            poses[i], ners[i], lemmas[i], dep_paths[i],
                            dep_parents[i], bounding_boxes[i])
                self.words.append(word)

    # Return a list of the indexes of all words in the dependency path from
    # the word at index word_index to the root
    def get_path_till_root(self, word_index):
        path = []
        c = word_index
        MAX_DEP_PATH_LEN = self._MAX_DEP_PATH_LEN
        while MAX_DEP_PATH_LEN > 0:
            MAX_DEP_PATH_LEN = MAX_DEP_PATH_LEN - 1
            try:
                # c == -1 means we found the root
                if c == -1:
                    break
                path.append(c)
                c = self.words[c].dep_parent
            except:
                break
        return path

    # Given two paths returned by get_path_till_root, find the least common
    # ancestor, i.e., the one farthest away from the root. If there is no
    # common ancestor, return None
    def get_common_ancestor(self, path1, path2):
        # The paths are sorted from leaf to root, so reverse them
        path1_rev = path1[:]
        path1_rev.reverse()
        path2_rev = path2[:]
        path2_rev.reverse()
        i = 0
        while i < min(len(path1_rev), len(path2_rev)) and \
                path1_rev[i] == path2_rev[i]:
            i += 1
        if path1_rev[i-1] != path2_rev[i-1]:
            # No common ancestor found
            return None
        else:
            return path1_rev[i-1]
        # XXX (Matteo) The following is the function as it was in pharma.
        # The logic seemed more complicated to understand for me.
        # parent = None
        # for i in range(max(len(path1), len(path2))):
        #     tovisit = 0 - i - 1
        #     if i >= len(path1) or i >= len(path2):
        #         break
        #     if path1[tovisit] != path2[tovisit]:
        #         break
        #     parent = path1[tovisit]
        # return parent

    # Given two word idx1 and idx2, where idx2 is an ancestor of idx1, return,
    # for each word 'w' on the dependency path between idx1 and idx2, the label
    # on the edge to 'w' and the NER tag of 'w' or its lemma if the NER tag
    # is 'O' (see Word.get_feature())
    # the dependency path labels on the path from idx1 to idx2
    def get_direct_dependency_path_between_words(
            self, idx1, idx2, use_pos=False):
        words_on_path = []
        c = idx1
        length = 0
        MAX_DEP_PATH_LEN = self._MAX_DEP_PATH_LEN
        while MAX_DEP_PATH_LEN > 0:
            MAX_DEP_PATH_LEN -= 1
            try:
                if c == -1:
                    break
                elif c == idx2:
                    break
                elif c == idx1:
                    # we do not include the NER tag/lemma for idx1
                    words_on_path.append(str(self.words[c].dep_path))
                else:
                    words_on_path.append(str(self.words[c].dep_path) + "|" +
                                         self.words[c].get_feature(use_pos))
                c = self.words[c].dep_parent
                length += 1
            except:
                break
        return (words_on_path, length)

    # Given two word idx1 and idx2, return the dependency path feature between
    # them
    def get_word_dep_path(self, idx1, idx2, use_pos=False):
        path1 = self.get_path_till_root(idx1)
        path2 = self.get_path_till_root(idx2)

        parent = self.get_common_ancestor(path1, path2)

        (words_from_idx1_to_parents, length_1) = \
            self.get_direct_dependency_path_between_words(
                idx1, parent, use_pos)
        (words_from_idx2_to_parents, length_2) = \
            self.get_direct_dependency_path_between_words(
                idx2, parent, use_pos)

        if parent is None:
            root_str = "@ROOT@"
        else:
            root_str = "@"

        return ("-".join(words_from_idx1_to_parents) + root_str +
                "-".join(words_from_idx2_to_parents), length_1 + length_2)

    # Given a mention, return the word before the first word of the mention,
    # if present
    def get_prev_wordobject(self, mention):
        begin = mention.words[0].in_sent_idx
        if begin - 1 < 0:
            return None
        else:
            return self.words[begin - 1]

    # Given a mention, return the word after the last word of the mention, if
    # present
    def get_next_wordobject(self, mention):
        end = mention.words[-1].in_sent_idx
        if end == len(self.words) - 1:
            return None
        else:
            return self.words[end + 1]

    def dep_parent(self, mention):
        begin = mention.words[0].in_sent_idx
        end = mention.words[-1].in_sent_idx

        paths = []
        for i in range(begin, end+1):
            for j in range(0, len(self.words)):
                if j >= begin and j <= end:
                    continue

                (path, length) = self.get_word_dep_path(i, j)
                paths.append(path)

        return sorted(paths, key=len)[0:min(5, len(paths))]

    # Given two entities, return the feature of the shortest dependency path
    # between a word from one of to a word of the other.
    def dep_path(self, entity1_words, entity2_words, use_pos=False):
        begin1 = entity1_words[0].in_sent_idx
        end1 = entity1_words[-1].in_sent_idx
        begin2 = entity2_words[0].in_sent_idx
        end2 = entity2_words[-1].in_sent_idx

        min_len = 10000000000
        min_p = None
        for idx1 in range(begin1, end1+1):
            for idx2 in range(begin2, end2+1):
                (path, length) = self.get_word_dep_path(idx1, idx2, use_pos)
                if length < min_len:
                    min_p = path
                    min_len = length
        return (min_p, min_len)

    # Return True if the sentence is 'weird', according to the following
    # criteria:
    # 1) It contains more than 12 floats
    # 2) It contains many "no" / "yes" / "na"
    # 3) It contains many "—"
    # 4) It contains many ";"
    # 5) It is longer than 150 words
    def is_weird(self):
        if len(self.words) > 150:
            return True
        count_floats = 0
        count_NA = 0
        count_minus = 0
        count_semicolon = 0
        for word in self.words:
            try:
                float(word.word)
                count_floats += 1
            except ValueError:
                pass
            if word.word in ["NA", "Yes", "No"]:
                count_NA += 1
            elif word.word == "—":
                count_minus += 1
            elif word.word == ";":
                count_semicolon += 1
        if count_floats > 12 or count_NA > 6 or count_minus > 10 or \
                count_semicolon > 6:
            return True
        else:
            return False
