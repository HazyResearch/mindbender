#! /usr/bin/env pypy

from lib import dd as ddlib
import re
import sys
import json

def load_dict (kb_formation_temporal, kb_formatioin_country):
	for l in open(ddlib.BASE_FOLDER + "/dicts/macrostrat_supervision.tsv"):
		(name1, n1, n2, n3, n4) = l.split('\t')
		name1 = name1.replace(' Fm', '').replace(' Mbr', '').replace(' Gp', '')
		n1 = float(n1)
		n2 = float(n2)
		n3 = float(n3)
		n4 = float(n4.rstrip())

		for rock in [name1.lower(), name1.lower() + " formation", name1.lower() + " member"]:
			if rock not in kb_formation_temporal:
				kb_formation_temporal[rock] = {}
				kb_formation_temporal[rock][(min(n1, n2, n3, n4), max(n1, n2, n3, n4))] = 1

	for l in open(ddlib.BASE_FOLDER + '/dicts/supervision_occurrences.tsv'):
		(reference_no, genus, species, formation, member, group, country, n1, n2, n3, n4) = l.split('\t')
		n1 = float(n1)
		n2 = float(n2)
		n3 = float(n3)
		n4 = float(n4.rstrip())
		
		formation = formation.lower() + " formation"
		member = member.lower() + " member"
		group = group.lower() + " group"
		
		for rock in [formation.lower()]:
			if rock not in kb_formation_country:
				kb_formation_temporal[rock] = {}
				kb_formation_country[rock] = {}
			kb_formation_country[rock][country] = {}
			kb_formation_temporal[rock][(min(n1, n2, n3, n4), max(n1, n2, n3, n4))] = 1

def main (entity1, entity2):
	kb_formation_temporal = {}
	kb_formation_country = {}
	load_dict (kb_formatioin_temporal, kb_formation_country)

	if entity1 in kb_formation_temporal:
		(name, large, small) = entity2.split('|')
		large = float(large)
		small = float(small)

		overlapped = False
		for (a,b) in kb_formation_temporal[entity1]:
			if max(b,large) - min(a,small) >= b-a + large-small :
				donothing = True
			else:
				overlapped = True

		yield None
		if overlapped == True:
			yield True
		else:
			yield False
	else:
		yield None
