#! /usr/bin/env python3

from helper.easierlife import BASE_DIR


# Load an example dictionary
# 1st column is doc id, 2nd is sentence ids (separated by '|'), 3rd is entity
def load_examples_dictionary(filename):
    examples = dict()
    with open(filename, 'rt') as examples_dict_file:
        for line in examples_dict_file:
            tokens = line.rstrip().split("\t")
            sent_ids = frozenset(tokens[1].split("|"))
            examples[frozenset([tokens[0], tokens[2]])] = sent_ids
            if tokens[1] == "":
                examples[frozenset([tokens[0], tokens[2]])] = None
    return examples


# Load the merged genes dictionary
def load_merged_genes_dictionary(filename):
    merged_genes_dict = dict()
    with open(filename, 'rt') as merged_genes_dict_file:
        for line in merged_genes_dict_file:
            tokens = line[:-1].split("\t")
            symbol = tokens[0]
            alternate_symbols = tokens[1].split("|")
            names = tokens[2].split("|")
            for sym in [symbol, ] + alternate_symbols + names:
                if sym not in merged_genes_dict:
                    merged_genes_dict[sym] = []
                merged_genes_dict[sym].append(symbol)
    return merged_genes_dict


# Load the genes dictionary
def load_genes_dictionary(filename):
    genes_dict = dict()
    with open(filename, 'rt') as genes_dict_file:
        for line in genes_dict_file:
            tokens = line.strip().split("\t")
            # first token is symbol, second is csv list of synonyms
            symbol = tokens[0]
            genes_dict[symbol] = symbol
            for synonym in tokens[1].split(","):
                genes_dict[synonym] = symbol
    return genes_dict


# Load the gene long names dictionary
def load_long_names_dictionary(filename):
    long_names_dict = dict()
    with open(filename, 'rt') as long_names_dict_file:
        for line in long_names_dict_file:
            tokens = line[:-1].split("\t")
            symbol = tokens[0]
            alternate_symbols = tokens[1].split("|")
            names = tokens[2].split("|")
            for sym in [symbol, ] + alternate_symbols:
                if sym not in long_names_dict:
                    long_names_dict[sym] = []
                long_names_dict[sym] += names
    return long_names_dict

# Load the inverted gene long names dictionary
def load_inverted_long_names_dictionary(filename):
    long_names_dict = dict()
    with open(filename, 'rt') as long_names_dict_file:
        for line in long_names_dict_file:
            tokens = line[:-1].split("\t")
            symbol = tokens[0]
            names = tokens[2].split("|")
            for name in names:
                if name not in long_names_dict:
                    long_names_dict[name] = []
                long_names_dict[name].append(symbol)
    return long_names_dict


def load_genes_in_hpoterms_dictionary(filename):
    genes_in_hpoterms_dict = dict()
    with open(filename, 'rt') as dict_file:
        for line in dict_file:
            tokens = line.strip().split("\t")
            if tokens[0] not in genes_in_hpoterms_dict:
                genes_in_hpoterms_dict[tokens[0]] = set()
            genes_in_hpoterms_dict[tokens[0]].add(tokens[1])
    return genes_in_hpoterms_dict


def load_hpoterms_with_gene_dictionary(filename):
    hpoterms_with_gene_dict = dict()
    with open(filename, 'rt') as dict_file:
        for line in dict_file:
            tokens = line.strip().split("\t")
            hpoterms_with_gene_dict[tokens[1]] = tokens[0]
    return hpoterms_with_gene_dict


def load_hpoterms_in_genes_dictionary(filename):
    hpoterms_in_genes_dict = dict()
    with open(filename, 'rt') as dict_file:
        for line in dict_file:
            tokens = line.strip().split("\t")
            if tokens[0] not in hpoterms_in_genes_dict:
                hpoterms_in_genes_dict[tokens[0]] = set()
            hpoterms_in_genes_dict[tokens[0]].add(tokens[1])
    return hpoterms_in_genes_dict


def load_genes_with_hpoterm_dictionary(filename):
    genes_with_hpoterm_dict = dict()
    with open(filename, 'rt') as dict_file:
        for line in dict_file:
            tokens = line.strip().split("\t")
            genes_with_hpoterm_dict[tokens[1]] = tokens[0]
    return genes_with_hpoterm_dict


# Load the HPO term levels
def load_hpoterm_levels_dictionary(filename):
    hpo_level_dict = dict()
    with open(filename, 'rt') as hpo_level_dict_file:
        for line in hpo_level_dict_file:
            hpo_id, name, c, level = line.strip().split("\t")
            level = int(level)
            if level not in hpo_level_dict:
                hpo_level_dict[level] = set()
            hpo_level_dict[level].add(hpo_id)
    return hpo_level_dict


# Load the HPO parents
def load_hpoparents_dictionary(filename):
    hpoparents_dict = dict()
    with open(filename, 'rt') as hpoparents_dict_file:
        for line in hpoparents_dict_file:
            child, is_a, parent = line.strip().split("\t")
            if child not in hpoparents_dict:
                hpoparents_dict[child] = set()
            hpoparents_dict[child].add(parent)
    # Add 'All'
    hpoparents_dict["HP:0000001"] = set(["HP:0000001", ])
    return hpoparents_dict


# Load the HPO ancestors
def load_hpoancestors_dictionary(filename):
    hpoparents_dict = load_hpoparents_dictionary(filename)

    def get_ancestors(key):
        if hpoparents_dict[key] == set([key, ]):
            return hpoparents_dict[key]
        else:
            parents = hpoparents_dict[key]
            ancestors = set(parents)
            for parent in parents:
                ancestors |= get_ancestors(parent)
            return ancestors
    hpoancestors_dict = dict()
    with open(filename, 'rt') as hpoancestors_dict_file:
        for line in hpoancestors_dict_file:
            child, is_a, parent = line.strip().split("\t")
            if child not in hpoancestors_dict:
                hpoancestors_dict[child] = get_ancestors(child)
    # Add 'All'
    hpoancestors_dict["HP:0000001"] = set(["HP:0000001", ])
    return hpoancestors_dict


# Load the HPO children
def load_hpochildren_dictionary(filename):
    hpochildren_dict = dict()
    with open(filename, 'rt') as hpochildren_dict_file:
        for line in hpochildren_dict_file:
            child, is_a, parent = line.strip().split("\t")
            if parent not in hpochildren_dict:
                hpochildren_dict[parent] = set()
            hpochildren_dict[parent].add(child)
    return hpochildren_dict


# Load the HPOterms original dictionary
# Terms are converted to lower case
def load_hpoterms_orig_dictionary(filename):
    hpoterms_dict = dict()
    with open(filename, 'rt') as hpoterms_dict_file:
        for line in hpoterms_dict_file:
            tokens = line.strip().split("\t")
            # 1st token is name, 2nd is description, 3rd is 'C' and 4th is
            # (presumably) the distance from the root of the DAG.
            name = tokens[0]
            description = tokens[1]
            # Skip "All"
            # XXX (Matteo) There may be more generic terms that we want to skip
            if description == "All":
                continue
            description_words = description.split()
            variants = get_variants(description_words)
            for variant in variants:
                hpoterms_dict[variant.casefold()] = name
    return hpoterms_dict


# Load the HPOterms 'mentions' dictionary (output of hpoterms2mentions.py)
# Maps stem sets to hpo names
def load_hpoterms_dictionary(filename):
    _hpoterms_dict = dict()
    with open(filename, 'rt') as _hpoterms_dict_file:
        for line in _hpoterms_dict_file:
            hpoterm_id, name, stems = line[:-1].split("\t")
            stems_set = frozenset(stems.split("|"))
            if stems_set not in _hpoterms_dict:
                _hpoterms_dict[stems_set] = set()
            _hpoterms_dict[stems_set].add(name)
    return _hpoterms_dict


# Load the inverted HPOterms 'mentions' dictionary
# Map hpo names to stem sets
def load_hpoterms_inverted_dictionary(filename):
    _hpoterms_dict = dict()
    with open(filename, 'rt') as _hpoterms_dict_file:
        for line in _hpoterms_dict_file:
            hpoterm_id, name, stems = line[:-1].split("\t")
            stems_set = frozenset(stems.split("|"))
            _hpoterms_dict[name] = stems_set
    return _hpoterms_dict


# Load the HPO "name" to "id" dictionary
def load_hponames_to_ids_dictionary(filename):
    _hpoterms_dict = dict()
    with open(filename, 'rt') as _hpoterms_dict_file:
        for line in _hpoterms_dict_file:
            hpoterm_id, name, stems = line[:-1].split("\t")
            _hpoterms_dict[name] = hpoterm_id
    return _hpoterms_dict


# Load the medical acronyms dictionary
def load_medacrons_dictionary(filename):
    medacrons_dict = dict()
    with open(filename, 'rt') as medacrons_dict_file:
        for line in medacrons_dict_file:
            tokens = line.strip().split("\t")
            # 1st token is acronym, 2nd is definition
            name = tokens[0]
            definition = tokens[1].casefold()
            medacrons_dict[definition] = name
    return medacrons_dict


# Load a dictionary which is a set.
def load_set(filename):
    _set = set()
    with open(filename, 'rt') as set_file:
        for line in set_file:
            line = line.rstrip()
            _set.add(line)
    return _set


# Load a dictionary which is a set, but convert the entries to lower case
def load_set_lower_case(filename):
    case_set = load_set(filename)
    lower_case_set = set()
    for entry in case_set:
        lower_case_set.add(entry.casefold())
    return lower_case_set


# Load a dictionary which is a set of pairs, where the pairs are frozensets
def load_set_pairs(filename):
    pair_set = set()
    with open(filename, 'rt') as set_file:
        for line in set_file:
            tokens = line.rstrip().split("\t")
            pair_set.add(frozenset(tokens[0:2]))
    return pair_set

# Dictionaries
GENES_DICT_FILENAME = BASE_DIR + "/dicts/hugo_synonyms.tsv"
GENES_IN_HPOTERMS_DICT_FILENAME = BASE_DIR + "/dicts/genes_in_hpoterms.tsv"
ENGLISH_DICT_FILENAME = BASE_DIR + "/dicts/english_words.tsv"
GENEHPOTERM_DICT_FILENAME = BASE_DIR + \
    "/dicts/genes_to_hpo_terms_with_synonyms.tsv"
HPOPARENTS_DICT_FILENAME = BASE_DIR + "/dicts/hpo_dag.tsv"
HPOTERMS_ORIG_DICT_FILENAME = BASE_DIR + "/dicts/hpo_terms.tsv"
# NON PRUNED HPOTERMS_DICT_FILENAME = BASE_DIR + "/dicts/hpoterm_mentions.tsv"
HPOTERMS_DICT_FILENAME = BASE_DIR + "/dicts/hpoterm_abnormalities_mentions.tsv"
HPOTERM_PHENOTYPE_ABNORMALITIES_DICT_FILENAME = BASE_DIR + \
    "/dicts/hpoterm_phenotype_abnormalities.tsv"
HPOTERMS_IN_GENES_DICT_FILENAME = BASE_DIR + "/dicts/hpoterms_in_genes.tsv"
MED_ACRONS_DICT_FILENAME = BASE_DIR + "/dicts/med_acronyms_pruned.tsv"
MERGED_GENES_DICT_FILENAME = BASE_DIR + "/dicts/merged_genes_dict.tsv"
NIH_GRANTS_DICT_FILENAME = BASE_DIR + "/dicts/grant_codes_nih.tsv"
NSF_GRANTS_DICT_FILENAME = BASE_DIR + "/dicts/grant_codes_nsf.tsv"
STOPWORDS_DICT_FILENAME = BASE_DIR + "/dicts/english_stopwords.tsv"
POS_GENE_MENTIONS_DICT_FILENAME = BASE_DIR + \
    "/dicts/positive_gene_mentions.tsv"
NEG_GENE_MENTIONS_DICT_FILENAME = BASE_DIR + \
    "/dicts/negative_gene_mentions.tsv"

# Dictionary of dictionaries. First argument is the filename, second is the
# function to call to load the dictionary. The function must take the filename
# as input and return an object like a dictionary, or a set, or a list, ...
dictionaries = dict()
dictionaries["genes"] = [GENES_DICT_FILENAME, load_genes_dictionary]
dictionaries["genes_in_hpoterms"] = [GENES_IN_HPOTERMS_DICT_FILENAME,
                                     load_genes_in_hpoterms_dictionary]
dictionaries["genes_with_hpoterm"] = [HPOTERMS_IN_GENES_DICT_FILENAME,
                                      load_genes_with_hpoterm_dictionary]
dictionaries["english"] = [ENGLISH_DICT_FILENAME, load_set_lower_case]
dictionaries["genehpoterms"] = [GENEHPOTERM_DICT_FILENAME, load_set_pairs]
dictionaries["hpoparents"] = [HPOPARENTS_DICT_FILENAME,
                              load_hpoparents_dictionary]
dictionaries["hpoancestors"] = [HPOPARENTS_DICT_FILENAME,
                                load_hpoancestors_dictionary]
dictionaries["hpochildren"] = [HPOPARENTS_DICT_FILENAME,
                               load_hpochildren_dictionary]
dictionaries["hpolevels"] = [HPOTERMS_ORIG_DICT_FILENAME,
                             load_hpoterm_levels_dictionary]
dictionaries["hponames_to_ids"] = [HPOTERMS_DICT_FILENAME,
                                   load_hponames_to_ids_dictionary]
dictionaries["hpoterms"] = [HPOTERMS_DICT_FILENAME, load_hpoterms_dictionary]
dictionaries["hpoterms_inverted"] = [HPOTERMS_DICT_FILENAME,
                                     load_hpoterms_inverted_dictionary]
dictionaries["hpoterm_phenotype_abnormalities"] = [
    HPOTERM_PHENOTYPE_ABNORMALITIES_DICT_FILENAME, load_set]
dictionaries["hpoterms_orig"] = [HPOTERMS_ORIG_DICT_FILENAME,
                                 load_hpoterms_orig_dictionary]
dictionaries["hpoterms_in_genes"] = [HPOTERMS_IN_GENES_DICT_FILENAME,
                                     load_hpoterms_in_genes_dictionary]
dictionaries["hpoterms_with_gene"] = [GENES_IN_HPOTERMS_DICT_FILENAME,
                                     load_hpoterms_with_gene_dictionary]
dictionaries["nih_grants"] = [NIH_GRANTS_DICT_FILENAME, load_set]
dictionaries["nsf_grants"] = [NSF_GRANTS_DICT_FILENAME, load_set]
dictionaries["med_acrons"] = [MED_ACRONS_DICT_FILENAME,
                              load_medacrons_dictionary]
dictionaries["merged_genes"] = [MERGED_GENES_DICT_FILENAME,
                                load_merged_genes_dictionary]
dictionaries["long_names"] = [MERGED_GENES_DICT_FILENAME,
                              load_long_names_dictionary]
dictionaries["inverted_long_names"] = [MERGED_GENES_DICT_FILENAME,
                                       load_inverted_long_names_dictionary]
dictionaries["stopwords"] = [STOPWORDS_DICT_FILENAME, load_set]
dictionaries["pos_gene_mentions"] = [POS_GENE_MENTIONS_DICT_FILENAME,
                                     load_examples_dictionary]
dictionaries["neg_gene_mentions"] = [NEG_GENE_MENTIONS_DICT_FILENAME,
                                     load_examples_dictionary]


# Load a dictionary using the appropriate filename and load function
def load_dict(dict_name):
    filename = dictionaries[dict_name][0]
    load = dictionaries[dict_name][1]
    return load(filename)


# Given a list of words, return a list of variants built by splitting words
# that contain the separator.
# An example is more valuable:
# let words = ["the", "cat/dog", "is", "mine"], the function would return ["the
# cat is mine", "the dog is mine"]
# XXX (Matteo) Maybe goes in a different module
def get_variants(words, separator="/"):
    if len(words) == 0:
        return []
    variants = []
    base = []
    i = 0
    # Look for a word containing a "/"
    while words[i].find(separator) == -1:
        base.append(words[i])
        i += 1
        if i == len(words):
            break
    # If we found a word containing a "/", call recursively
    if i < len(words):
        variants_starting_words = words[i].split("/")
        following_variants = get_variants(words[i+1:])
        for variant_starting_word in variants_starting_words:
            variant_base = base + [variant_starting_word]
            if len(following_variants) > 0:
                for following_variant in following_variants:
                    variants.append(" ".join(variant_base +
                                             [following_variant]))
            else:
                variants.append(" ".join(variant_base))
    else:
        variants = [" ".join(base)]
    return variants
