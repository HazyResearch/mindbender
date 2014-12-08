#! /usr/bin/env pypy

from lib import dd as ddlib
import re
import sys
import json

def aux (entitiesWithTypes):
	good_names = {}
	local_entity_types = {}
	local_entities = {}
	for et in entitiesWithTypes:
	        ent = et.entity
		local_entities[ent] = 1
		good_names[ent] = ent
		good_names[ent[0:ent.rindex(' ')]] = ent
		local_entity_types[ent] = et.type
	return {"good_names":good_names, "local_entities":local_entities, "local_entity_types":local_entity_types}

def main (words, lemmas, all_phrases, good_names, local_entities, local_entity_types):
	for (start, end) in all_phrases:
		phrase = " ".join(words[start:end])
		lemma = " ".join(lemmas[start:end])
		lemma = lemma.replace('Sandstones', 'Sandstone')

		if phrase.lower() in good_names:
			c = True
			if phrase.lower() not in local_entities:
				name = good_names[phrase.lower()]
				yield {"start": start, "end": end,
					   "type": local_entity_types[name], "entity": name, "is_correct": None}

