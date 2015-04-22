#! /usr/bin/env python3
#
# Map phenotype abnormalities entities to mentions

import sys
from nltk.stem.snowball import SnowballStemmer

from helper.dictionaries import load_dict

ORDINALS = frozenset(
    ["1st", "2nd", "3rd", "4th" "5th", "6th" "7th", "8th", "9th", "first",
        "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth"
        "ninth"])


def main():
    # Load the dictionaries we need
    stopwords_dict = load_dict("stopwords")
    hpoterm_phenotype_abnormalities = load_dict(
        "hpoterm_phenotype_abnormalities")
    # Load the stemmer from NLTK
    stemmer = SnowballStemmer("english")
    if len(sys.argv) != 2:
        sys.stderr.write("USAGE: {} DICT\n".format(sys.argv[0]))
        sys.exit(1)
    with open(sys.argv[1], 'rt') as dict_file:
        for line in dict_file:
            # Skip empty lines
            if line.strip() == "":
                continue
            hpo_id, name, definition = line.strip().split("\t")
            # Skip if this is not a phenotypic abnormality
            if hpo_id not in hpoterm_phenotype_abnormalities:
                    continue
            tokens = name.split()
            if len(tokens) == 1:
                name_stems = [tokens[0].casefold(), ]
            else:
                # Compute the stems of the name
                name_stems = set()
                for word in tokens:
                    # Remove parenthesis and commas and colons
                    if word[0] == "(":
                        word = word[1:]
                    if word[-1] == ")":
                        word = word[:-1]
                    if word[-1] == ",":
                        word = word[:-1]
                    if word[-1] == ":":
                        word = word[:-1]
                    # Only process non stop-words AND single letters
                    if (word.casefold() not in stopwords_dict and word not in
                            ORDINALS) or len(word) == 1:
                        # split words that contain a "/"
                        if word.find("/") != - 1:
                            for part in word.split("/"):
                                name_stems.add(stemmer.stem(part))
                        else:
                            name_stems.add(stemmer.stem(word))
            print("\t".join([hpo_id, name, "|".join(name_stems)]))


if __name__ == "__main__":
    sys.exit(main())
