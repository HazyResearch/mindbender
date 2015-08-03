### jq functions and variables for processing schema exported from DDlog programs

# anchor at the schmea root
. as $DDlogSchema |

## shorthand for enumeration
# relations declared
def relations:
    $DDlogSchema | .relations | to_entries | map(.value.name = .key | .value) | .[]
;

# columns of a relation
def columns:
    .columns | to_entries | map(.value.name = .key | .value) | .[]
;

## shorthand for annotations
def annotations(pred):
    if .annotations then .annotations[] | select(pred) else empty end
;
# e.g.: relations | annotated(.name == "textspan") | columns | annotated(.name == "key")
def annotated(withAnnotation):
    select([annotations(withAnnotation)] | length > 0)
;
def hasColumnsAnnotated(withAnnotation):
    select([columns | annotated(withAnnotation)] | length > 0)
;

# @key columns
def keyColumns:
    [columns | annotated(.name == "key")]
;
def keyColumn:
    keyColumns | if length > 1 then empty else .[0] end
;

# columns that @references to other relations
# It's a little complicated to support relations with multiple keys.
# columns with @references to the same relation="R")
def relationsReferenced:
    [columns | annotated(.name == "references") |
            (annotations(.name == "references") | .args) + { byColumn: . }] |
    group_by(.relation) | map(
            sort_by(.column) |
            { relation: .[0].relation, column: map(.column), byColumn: map(.byColumn) }
        )
;

## shorthand for SQL generation
def sqlForRelation:
    "SELECT \(.columns | keys | join(", ")) FROM \(.name)"
;
