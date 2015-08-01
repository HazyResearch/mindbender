def relations:
    .relations | to_entries | map(.value.relation = .key | .value) | .[]
;

def annotated(annoName):
    annoName as $annoName |
    select(.annotations and (.annotations[] | select(.name == $annoName)))
;

def relationsAnnotated(annoName):
    relations | annotated(annoName)
;

def sqlForRelation:
    "SELECT " + (.columns | keys | join(", ")) + " FROM " + .relation
;
