#! /usr/bin/env python3

from helper.dictionaries import load_dict

if __name__ == "__main__":
    merged_genes_dict = load_dict("merged_genes")
    inverted_long_names = load_dict("inverted_long_names")
    hpoterms_orig = load_dict("hpoterms_orig")

    for hpoterm_name in hpoterms_orig:
        for long_name in inverted_long_names:
            if hpoterm_name in long_name.split() and \
                    hpoterm_name.casefold() != long_name.casefold:
                print("\t".join((hpoterm_name, long_name)))
