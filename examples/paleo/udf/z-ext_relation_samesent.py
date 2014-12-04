#! /usr/bin/env pypy

from lib import dd as ddlib
import re
import sys
import json
import collections

ranks = {"subspecies":1,"species":2,"subgenus":3,"genus":4,"subtribe":5,
		 "tribe":6,"subfamily":7,"family":8,"group":9,"superfamily":10,
		 "infraorder":11,"suborder":12,"order":13,"superorder":14,"infraclass":15,
		 "subclass":16,"class":17,"superclass":18,"subphylum":19,"phylum":20,
		 "superphylum":21,"subkingdom":22,"kingdom":23,"superkingdom":24}
Mention = collections.namedtuple('Mention', ['entity_obj', 'type', 'start', 'end', 'entity'])

def wordseq_feature (e1, e2, words, ners):
    begin1 = e1.start
    end1 = e1.end
    begin2 = e2.start
    end2 = e2.end

    start = end1 + 1
    finish = begin2 - 1
    prefix = ""

    if end2 <= begin1:
        start = end2 + 1
        finish = begin1 - 1
        prefix = "INV:"

    ss = []
    for w in range(start, min(finish + 1, len(words))):
        if ners[w] == 'O':
            ss.append(words[w].encode('ascii', 'ignore'))
        else:
            ss.append(ners[w])
    return prefix + "_".join(ss)

def aux (sentid, ents_entity_obj, ents_type, ents_sentid, ents_start, ents_end, ents_entity):
	entities = []
	for i in range(len(ents_entity_obj)):
		if ents_sentid[i] == sentid:
			entities.append(Mention(ents_entity_obj[i], ents_type[i].split('-')[-1],
									ents_start[i], ents_end[i], ents_entity[i]))
	return entities

def main (words, ners, entities):
  	if len(entities) < 2: pass

	rels ={}
	rels['FORMATIONLOCATION']={}

	for e1 in entities:
		for e2 in entities:
			if 'species' in e1.type and 'genus' in e2.type and \
					e1.entity.lower().startswith(e2.entity.lower()): continue
			if e1 == e2: continue

			ws = wordseq_feature(e1, e2, words, ners)
			features = "[SAMESENT PROV=" + ws + "] "
                
			if e1.type in ranks and e2.type in ranks:
				if ranks[e1.type] < ranks[e2.type]:
					yield {"e1":e1.entity_obj, "e2":e2.entity_obj, "features":features, "type":"TAXONOMY"}

			if ';' in ws and len(words) > 10: continue
                    
			if e1.type not in ['FORMATION', 'LOCATION', 'INTERVAL'] and e2.type == 'LOCATION':
				yield {"e1":e1.entity_obj, "e2":e2.entity_obj, "features":features, "type":"LOCATION"}

			if e1.type not in ['FORMATION', 'LOCATION', 'INTERVAL'] and e2.type == 'FORMATION':
				yield {"e1":e1.entity_obj, "e2":e2.entity_obj, "features":features, "type":"FORMATION"}

			if e1.type == 'FORMATION' and e2.type == 'LOCATION':
				yield {"e1":e1.entity_obj, "e2":e2.entity_obj, "features":features, "type":"FORMATIONLOCATION"}

			if e1.entity not in rels['FORMATIONLOCATION']:
				rels['FORMATIONLOCATION'][e1.entity] = (math.fabs(e1.start-e2.start), e1, e2) 
			else:
				if math.fabs(e1.start-e2.start) < rels['FORMATIONLOCATION'][e1.entity][0]:
					rels['FORMATIONLOCATION'][e1.entity]=(math.fabs(e1.start-e2.start), e1, e2)
					
			if e1.type == 'FORMATION' and e2.type == 'INTERVAL':
				yield {"e1":e1.entity_obj, "e2":e2.entity_obj, "features":features, "type":"FORMATIONINTERVAL"}

	for ent in rels['FORMATIONLOCATION']:
		e1 = rels['FORMATIONLOCATION'][ent][1]
		e2 = rels['FORMATIONLOCATION'][ent][2]
		ddlib.log("~~~~~~~~~~~~~~")
		yield {"e1":e1.entity_obj, "e2":e2.entity_obj, "features":"[SAMESENT-NEAREST]", "type":"FORMATIONINTERVAL"}
