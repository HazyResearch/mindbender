#! /usr/bin/env python3
#
# Extract gene mention candidates and perform distant supervision
#

import fileinput
import re

from dstruct.Sentence import Sentence
from helper.dictionaries import load_dict
from helper.easierlife import get_dict_from_TSVline, TSVstring2list, no_op, \
    print_feature, BASE_DIR

import ddlib


def add_features_generic(mention_id, gene_words, sentence):
    # Use the generic feature library (ONLY!)

    # Load dictionaries for keywords
    ddlib.load_dictionary(BASE_DIR + "/dicts/features/gene_var.tsv",  "VARKW")
    ddlib.load_dictionary(
        BASE_DIR + "/dicts/features/gene_knock.tsv",  "KNOCKKW")
    ddlib.load_dictionary(
        BASE_DIR + "/dicts/features/gene_amino.tsv",  "AMINOKW")
    ddlib.load_dictionary(
        BASE_DIR + "/dicts/features/gene_antigene.tsv",  "ANTIGENEKW")
    ddlib.load_dictionary(BASE_DIR + "/dicts/features/gene_dna.tsv",  "DNAKW")
    ddlib.load_dictionary(
        BASE_DIR + "/dicts/features/gene_downregulation.tsv",  "DOWNREGKW")
    ddlib.load_dictionary(
        BASE_DIR + "/dicts/features/gene_upregulation.tsv",  "UPREGKW")
    ddlib.load_dictionary(
        BASE_DIR + "/dicts/features/gene_tumor.tsv",  "TUMORKW")
    ddlib.load_dictionary(
        BASE_DIR + "/dicts/features/gene_gene.tsv",  "GENEKW")
    ddlib.load_dictionary(
        BASE_DIR + "/dicts/features/gene_expression.tsv",  "EXPRESSKW")
    # Create the objects used by ddlib. ddlib interface is so ugly.
    obj = dict()
    obj['lemma'] = []
    obj['words'] = []
    obj['ner'] = []
    obj['pos'] = []
    obj['dep_graph'] = []
    for word in sentence.words:
        obj['lemma'].append(word.lemma)
        obj['words'].append(word.word)
        obj['ner'].append(word.ner)
        obj['pos'].append(word.pos)
        obj['dep_graph'].append(
            str(word.dep_parent + 1) + "\t" + word.dep_path + "\t" +
            str(word.in_sent_idx + 1))
    word_obj_list = ddlib.unpack_words(
        obj, lemma='lemma', pos='pos', ner='ner', words='words',
        dep_graph='dep_graph', dep_graph_parser=ddlib.dep_graph_parser_triplet)
    gene_span = ddlib.get_span(gene_words[0].in_sent_idx, len(gene_words))
    features = set()
    for feature in ddlib.get_generic_features_mention(
            word_obj_list, gene_span):
        features.add(feature)
    for feature in features:
        print_feature(sentence.doc_id, mention_id, feature)


# Keywords that are often associated with genes
VAR_KWS = frozenset([
    "acetylation", "activate", "activation", "adaptor", "agonist", "alignment",
    "allele", "antagonist", "antibody", "asynonymous", "backbone", "binding",
    "biomarker", "breakdown", "cell", "cleavage", "cluster", "cnv",
    "coactivator", "co-activator",  "complex", "dd-genotype", "DD-genotype",
    "deletion", "determinant", "domain", "duplication", "dysfunction",
    "effector", "enhancer", "enrichment", "enzyme", "excision", "factor",
    "family",  "function", "functionality", "genotype",
    "growth", "haplotype", "haplotypes", "heterozygous", "hexons", "hexon",
    "histone", "homologue", "homology", "homozygous" "human",
    "hypermetylation", "hybridization", "induce", "inducer", "induction",
    "inhibitor", "inhibition", "intron", "interaction", "isoform", "isoforms",
    "kinase", "kinesin", "level", "ligand", "location", "locus",
    "mammalian", "marker", "methilation", "modification", "moiety", "molecule",
    "molecules", "morpheein", "motif",  "mutant", "mutation",
    "mutations", "nonsynonymous", "non-synonymous", "nucleotide",
    "oligomerization", "oncoprotein", "pathway", "peptide",
    "pharmacokinetic", "pharmacodynamic", "pharmacogenetic" "phosphorylation",
    "polymorphism", "proliferation", "promoter", "protein", "receptor",
    "receptors", "recruitment", "region", "regulator", "release", "repressor",
    "resistance", "retention", "ribonuclease", "role", "sequence",
    "sequences", "sequestration", "serum", "signaling", "SNP", "SNPs",
    "staining", "sumoylation", "synonymous", "target", "T-cell", "transducer",
    "translocation", "transcribe", "transcript", "transcription",
    "transporter", "variant", "variation", "vivo", "vitro"
    ])

KNOCK_KWS = frozenset([
    "knockdown", "knock-down", "knock-out", "knockout", "KO"])

AMINO_ACID_KWS = frozenset(["amino-acid", "aminoacid"])

ANTIGENE_KWS = frozenset(["antigen", "antigene", "anti-gen", "anti-gene"])

DNA_KWS = frozenset([
    "cdna", "cDNA", "dna", "mrna", "mRNA", "rna", "rrna", "sirnas", "sirna",
    "siRNA", "siRNAs"])

DOWNREGULATION_KWS = frozenset(["down-regulation", "downregulation"])

UPREGULATION_KWS = frozenset(["up-regulation", "upregulation"])

TUMOR_KWS = frozenset([
    "tumor", "tumours", "tumour", "cancer", "carcinoma", "fibrosarcoma",
    "sarcoma", "lymphoma"])

GENE_KWS = frozenset([
    "gene", "oncogene", "protooncogene", "proto-oncogene", "pseudogene",
    "transgene"])

COEXPRESSION_KWS = frozenset([
    "expression", "overexpression", "over-expression", "co-expression",
    "coexpression"])


KEYWORDS = VAR_KWS | KNOCK_KWS | AMINO_ACID_KWS | ANTIGENE_KWS | DNA_KWS | \
    DOWNREGULATION_KWS | DOWNREGULATION_KWS | TUMOR_KWS | GENE_KWS | \
    COEXPRESSION_KWS

# Load the dictionaries that we need
merged_genes_dict = load_dict("merged_genes")
long_names_dict = load_dict("long_names")
inverted_long_names = load_dict("inverted_long_names")
hpoterms_with_gene = load_dict("hpoterms_with_gene")
stopwords_dict = load_dict("stopwords")


# Add features to a gene mention candidate
def add_features(mention_id, mention_words, sentence):
    # The verb closest to the candidate, with the path to it.
    minl = 100
    minp = None
    minw = None
    for word in mention_words:
        for word2 in sentence.words:
            if word2.lemma.isalpha() and re.search('^VB[A-Z]*$', word2.pos) \
                    and word2.lemma != 'be':
                # Ignoring "be" comes from pharm (Emily)
                (p, l) = sentence.get_word_dep_path(
                    word.in_sent_idx, word2.in_sent_idx)
                if l < minl:
                  minl = l
                  minp = p
                  minw = word2.lemma
    if minw:
        print_feature(
            sentence.doc_id, mention_id, 'VERB_[' + minw + ']' + minp)
    # The keywords that appear in the sentence with the mention
    minl = 100
    minp = None
    minw = None
    for word in mention_words:
        for word2 in sentence.words:
            if word2.lemma in KEYWORDS:
                (p, l) = sentence.get_word_dep_path(
                    word.in_sent_idx, word2.in_sent_idx)
                kw = word2.lemma
                if word2.lemma in KNOCK_KWS:
                    kw = "_KNOCKOUT"
                elif word2.lemma in ANTIGENE_KWS:
                    kw = "_ANTIGENE"
                elif word2.lemma in AMINO_ACID_KWS:
                    kw = "_AMINOACID"
                # elif word2.lemma in DNA_KWS:
                #    kw = "_DNA"
                elif word2.lemma in DOWNREGULATION_KWS:
                    kw = "_DOWNREGULATION"
                elif word2.lemma in UPREGULATION_KWS:
                    kw = "_UPREGULATION"
                # elif word2.lemma in TUMOR_KWS:
                #     kw = "_TUMOR"
                # elif word2.lemma in GENE_KWS:
                #     kw = "_GENE"
                # elif word2.lemma in COEXPRESSION_KWS:
                #    ke = "_COEXPRESSION"
                if l < minl:
                    minl = l
                    minp = p
                    minw = kw
                if len(p) < 100:
                    print_feature(
                        sentence.doc_id, mention_id,
                        "KEYWORD_[" + kw + "]" + p)
    # Special features for the keyword on the shortest dependency path
    if minw:
        print_feature(
            sentence.doc_id, mention_id,
            'EXT_KEYWORD_MIN_[' + minw + ']' + minp)
        print_feature(
            sentence.doc_id, mention_id, 'KEYWORD_MIN_[' + minw + ']')
    # If another gene is present in the sentence, add a feature with that gene
    # and the path to it. This comes from pharm.
    minl = 100
    minp = None
    minw = None
    mention_wordidxs = []
    for word in mention_words:
        mention_wordidxs.append(word.in_sent_idx)
    for word in mention_words:
        for word2 in sentence.words:
            if word2.in_sent_idx not in mention_wordidxs and \
                    word2.word in merged_genes_dict:
                (p, l) = sentence.get_word_dep_path(
                    word.in_sent_idx, word2.in_sent_idx)
                if l < minl:
                    minl = l
                    minp = p
                    minw = word2.lemma
    if minw:
        print_feature(
            sentence.doc_id, mention_id, 'OTHER_GENE_['+minw+']' + minp)
        # print_feature(sentence.doc_id, mention_id, 'OTHER_GENE_['+minw+']')
    # The lemma on the left of the candidate, whatever it is
    try:
        left = sentence.words[mention_words[0].in_sent_idx-1].lemma
        try:
            float(left)
            left = "_NUMBER"
        except ValueError:
            pass
        print_feature(
            sentence.doc_id, mention_id, "NGRAM_LEFT_1_[" + left + "]")
    except IndexError:
        pass
    # The lemma on the right of the candidate, whatever it is
    try:
        right = sentence.words[mention_words[-1].in_sent_idx+1].lemma
        try:
            float(right)
            right = "_NUMBER"
        except ValueError:
            pass
        print_feature(
            sentence.doc_id, mention_id, "NGRAM_RIGHT_1_[" + right + "]")
    except IndexError:
        pass
    # We know check whether the lemma on the left and on the right are
    # "special", for example a year or a gene.
    # The concept of left or right is a little tricky here, as we are actually
    # looking at the first word that contains only letters and is not a
    # stopword.
    idx = mention_words[0].in_sent_idx - 1
    gene_on_left = None
    gene_on_right = None
    while idx >= 0 and \
            ((((not sentence.words[idx].lemma.isalnum() and not
                sentence.words[idx] in merged_genes_dict) or
                (not sentence.words[idx].word.isupper() and
                 sentence.words[idx].lemma in stopwords_dict)) and
                not re.match("^[0-9]+(.[0-9]+)?$", sentence.words[idx].word)
                and not sentence.words[idx] in merged_genes_dict) or
                len(sentence.words[idx].lemma) == 1):
        idx -= 1
    if idx >= 0:
        if sentence.words[idx].word in merged_genes_dict and \
                len(sentence.words[idx].word) > 3:
            gene_on_left = sentence.words[idx].word
        try:
            year = float(sentence.words[idx].word)
            if round(year) == year and year > 1950 and year <= 2014:
                print_feature(sentence.doc_id, mention_id, "IS_YEAR_LEFT")
        except:
            pass
    # The word on the right of the mention, if present, provided it's
    # alphanumeric but not a number
    idx = mention_words[-1].in_sent_idx + 1
    while idx < len(sentence.words) and \
        ((((not sentence.words[idx].lemma.isalnum() and not
            sentence.words[idx] in merged_genes_dict) or
            (not sentence.words[idx].word.isupper() and
                sentence.words[idx].lemma in stopwords_dict)) and
            not re.match("^[0-9]+(.[0-9]+)?$", sentence.words[idx].word)
            and not sentence.words[idx] in merged_genes_dict) or
            len(sentence.words[idx].lemma) == 1):
        idx += 1
    if idx < len(sentence.words):
        if sentence.words[idx].word in merged_genes_dict and \
                len(sentence.words[idx].word) > 3:
            gene_on_right = sentence.words[idx].word
        try:
            year = float(sentence.words[idx].word)
            if round(year) == year and year > 1950 and year <= 2014:
                print_feature(sentence.doc_id, mention_id, "IS_YEAR_RIGHT")
        except:
            pass
    if gene_on_left and gene_on_right:
        print_feature(sentence.doc_id, mention_id, "IS_BETWEEN_GENES")
    elif gene_on_left:
        print_feature(sentence.doc_id, mention_id, "GENE_ON_LEFT")
    elif gene_on_right:
        print_feature(sentence.doc_id, mention_id, "GENE_ON_RIGHT")
    # The candidate is a single word that appears many times (more than 4) in
    # the sentence
    if len(mention_words) == 1 and \
            [w.word for w in sentence.words].count(mention_words[0].word) > 4:
        print_feature(
            sentence.doc_id, mention_id, "APPEARS_MANY_TIMES_IN_SENTENCE")
    # There are many PERSONs/ORGANIZATIONs/LOCATIONs in the sentence
    # for ner in ["PERSON", "ORGANIZATION", "LOCATION"]:
    #    if [x.ner for x in sentence.words].count(ner) > 4:
    #        print_feature(
    #           sentence.doc_id, mention_id, "MANY_{}_IN_SENTENCE".format(ner))


if __name__ == "__main__":
    # Process the input
    with fileinput.input() as input_files:
        for line in input_files:
            # Parse the TSV line
            line_dict = get_dict_from_TSVline(
                line, ["doc_id", "sent_id", "wordidxs", "words", "poses",
                       "ners", "lemmas", "dep_paths", "dep_parents",
                       "mention_id", "mention_wordidxs"],
                [no_op, int, lambda x: TSVstring2list(x, int), TSVstring2list,
                    TSVstring2list, TSVstring2list, TSVstring2list,
                    TSVstring2list, lambda x: TSVstring2list(x, int),
                    no_op, lambda x: TSVstring2list(x, int)])
            # Create the sentence object
            null_list = [None, ] * len(line_dict["wordidxs"])
            sentence = Sentence(
                line_dict["doc_id"], line_dict["sent_id"],
                line_dict["wordidxs"], line_dict["words"], line_dict["poses"],
                line_dict["ners"], line_dict["lemmas"], line_dict["dep_paths"],
                line_dict["dep_parents"], null_list)
            if sentence.is_weird():
                continue
            mention_words = []
            for mention_wordidx in line_dict["mention_wordidxs"]:
                mention_words.append(sentence.words[mention_wordidx])
            add_features(line_dict["mention_id"], mention_words, sentence)
            # add_features_generic( line_dict["mention_id"], mention_words,
            # sentence)
