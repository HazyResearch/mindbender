### jq functions and variables for processing schema exported from DDlog programs

# anchor at the schmea root
. as $DDlogSchema |

## shorthand for enumeration
# relations declared
def relations:
    $DDlogSchema | .relations | to_entries | map(.value.name = .key | .value) | .[]
;

# relations selected via $relations
((env.DDLOG_RELATIONS_SELECTED // "[]") | fromjson |
        if length > 0
        then map({ key: . }) | from_entries
        else null
        end
) as $RelationsSelected |
#def in(obj): (. as $__in_key | obj | has($__in_key)); # XXX shim for jq-1.4
def relationsSelected:
    relations | select($RelationsSelected == null or (.name | in($RelationsSelected)))
;

def relationByName:
    . as $relationName |
    relations | select(.name == $relationName)
;

# columns of a relation
def columns:
    .columns | to_entries | map(.value.name = .key | .value) | .[]
;

## shorthand for annotations
def annotations(pred):
    if .annotations then .annotations[] | select(pred) else empty end
;
def isAnnotated(withAnnotation):
    [annotations(withAnnotation)] | length > 0
;
# e.g.: relations | annotated(.name == "textspan") | columns | annotated(.name == "key")
def annotated(withAnnotation):
    select(isAnnotated(withAnnotation))
;
def notAnnotated(withAnnotation):
    select(isAnnotated(withAnnotation) | not)
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
# columns with @references to the same relation="R", but possibly with different alias=1,2,3...
def relationsReferencedByThisRelation:
    .name as $relationsReferencedByThisRelationName |
    [columns | annotated(.name == "references") |
            (annotations(.name == "references") | .args) + { byColumn: . }] |
    group_by("\(.relation) \(.alias)") |
    map(sort_by(.column) |
        { relation: .[0].relation
        , column: map(.column)
        , byColumn: map(.byColumn)
        , alias: (.[0].alias // .[0].byColumn.name)
        , byRelation: $relationsReferencedByThisRelationName }
    )
;
def relationsReferenced: relationsReferencedByThisRelation ; # XXX legacy
def relationsReferencingThisRelation:
    .name as $relationsReferencingThisRelationName |
    [
        relations |
        relationsReferencedByThisRelation[] |
        select(.relation == $relationsReferencingThisRelationName)
    ]
;

## schema graph traversal for search document model
# build a spanning tree from the current relation
def relationSubgraphForSearchFromRelation(parentRelation):
    # TODO detect cycles
    # TODO limit nestingLevel
    . as $this |
    { relation: $this
    , references: [
            relationsReferencedByThisRelation[] |
            # don't nest @source relations
            if (.relation != parentRelation) and
               (.relation | relationByName | isAnnotated(.name == "source") | not)
            then .graph = (.relation | relationByName |
                           relationSubgraphForSearchFromRelation($this.name))
            else .
            end
        ]
    , referencedBy: [
            relationsReferencingThisRelation[] |
            # don't nest other @extraction relations that references this
            if (.byRelation != parentRelation) and
               (.byRelation | relationByName | isAnnotated(.name == "extraction") | not)
            then .graph = (.byRelation | relationByName |
                           relationSubgraphForSearchFromRelation($this.name))
            else .
            end
        ]
    }
;
def relationSubgraphForSearchFromRelation: relationSubgraphForSearchFromRelation(null);

# from the subgraph, enumerate all qualified field names, e.g., R.Q.col1, R.Q.col2, that meet given conditions
def allNestedFields(selectColumn):
    # first enumerate all nodes with its path
    {path:[], graph:.} | recurse(
        . as $this |
        .graph | (
            .references[] | select(.graph) |
            .path = $this.path + [.alias]
        ), (
            .referencedBy[] | select(.graph) |
            .path = $this.path + ["\(.byRelation)_\(.alias)"]
        )
    ) |
    # turn each node into qualified field names
    [.path + (.graph.relation | columns | selectColumn | [.name]) | join(".")][]
;

# enumerate the @source relation names this one @references
def sourceRelations:
    # TODO use relationSubgraphForSearchFromRelation instead
    relationsReferenced[] |
    select(.relation | relationByName | isAnnotated(.name == "source"))
;
def sourceRelationsFixWIP:
    relationSubgraphForSearchFromRelation |
    { graph: . } | recurse(.graph | .references[]; .graph) |
    select(.graph | .relation | relationByName | isAnnotated(.name == "source"))

# SQL query for unloading a relation from PostgreSQL database with associated relations nested
def sqlForRelationNestingAssociated(indent; nestingLevel; parentRelation):
    "\n\(indent)" as $indent |

    # collect some info about this relation
    # TODO use relationSubgraphForSearchFromRelation instead
    . as $this |
    { this: .
    , references: [
            relationsReferencedByThisRelation[] |
            # don't nest @source relations
            select(.relation | relationByName | isAnnotated(.name == "source") | not) |
            select(.relation != parentRelation)
        ]
    , referencedBy: [
            relationsReferencingThisRelation[] |
            # don't nest other @extraction relations that references this
            select(.byRelation | relationByName | isAnnotated(.name == "extraction") | not) |
            select(.relation != parentRelation)
        ]
    } |

    # decide which columns to export
    .columns = [
        .this | columns |
        # TODO should we limit to @searchable/@navigable columns only?
        .name
    ] |
        # XXX removing these break jqForBulkLoadingRelationIntoElasticsearch below
        # # columns for referencing other relations should be dropped
        # - [.references[] | .byColumn[] | .name] |

    # derive join conditions
    (
    .joinConditions = [(
        .references[] |
        . as $ref | range(.column | length) | . as $i | $ref |
        # this relation
        {  left: { alias:   .byRelation, column: .byColumn[$i] | .name }
        # relation referenced by this
        , right: { alias: "__\(.alias)", column: .column[$i] }
        }
    ), (
        .referencedBy[] |
        . as $ref | range(.column | length) | . as $i | $ref |
        # this relation
        {  left: { alias:                  .relation, column: .column[$i] }
        # relation referencing this
        , right: { alias: "\(.byRelation)_\(.alias)", column: .byColumn[$i] | .name }
        }
    )]
    )|

    # produce SQL query
    "SELECT \(
        # columns on this relation
        [ (.columns[] | "\($this.name).\(.)")
        # variable relations have an extra expectation column
        , (if .this.variable_type then "\($this.name).expectation" else empty end)
        # nested rows of relations referenced by this relation
        , (.references[] | "__\(.alias) AS \(.alias)")
        # nested arrays of rows of relations referencing this relation
        , (.referencedBy[] | "\(.byRelation)_\(.alias).arr AS \(.byRelation)_\(.alias)")
        ] |
        join(
    "\($indent)     , ")

    )\($indent)  FROM \(
        # this relation
        [(if .this.variable_type then
            # variable relations should join DeepDive's inference result
            { alias: .this.name
            , expr:  "(SELECT \(
                [ "v.*"
                , "i.expectation"
                ] |
                join(
    "\($indent)             , ")
    )\($indent)          FROM \(
                [ "\(.this.name) v"
                , "\(.this.name)_label_inference i"
                ] |
                join(
    "\($indent)             , ")
    )\($indent)         WHERE \(
                [ "v.id = i.id"
                ] |
                join(
    "\($indent)           AND ")
    )\($indent)       )"
            }
          else
            # normal relation
            { alias: ""
            , expr: .this.name
            }
          end)

        # relations referenced by this relation
        , (.references[] |
          { alias: "__\(.alias)"
          , expr: "(\(
            .relation | relationByName |
            sqlForRelationNestingAssociated(
              "        " + indent; nestingLevel + 1; .byRelation)
    )\($indent)       )"
          })

        # relations referencing this relation
        , (.referencedBy[] |
          { alias: "\(.byRelation)_\(.alias)"
          , expr:    "(SELECT \(
            # TODO use the only column to create a flat array when R is a single column excluding all @references columns
            [ "ARRAY_AGG(R) arr"
            , (.byColumn[] | .name)
            ] |
            join(
    "\($indent)             , ")
    )\($indent)          FROM (\(
            .byRelation | relationByName |
            sqlForRelationNestingAssociated(
                "                " + indent; nestingLevel + 1; .relation))) \("R"
    )\($indent)         GROUP BY \(
            [ .byColumn[] | .name
            ] |
            join(
    "\($indent)                , ")
    )\($indent)       )"
          })
        ] |
        map("\(.expr) \(.alias)") |
        join(
    "\($indent)     , ")
    
    )\(
        if .joinConditions | length == 0 then "" else "\(""
    )\($indent) WHERE \(
        .joinConditions |
        map("\(.left.alias).\(.left.column) = \(.right.alias).\(.right.column)") |
        join(
    "\($indent)   AND ")
        )" end
    )"
;
def sqlForRelationNestingAssociated:
    sqlForRelationNestingAssociated(""; 0; null)
;

## shorthand for SQL generation
def sqlForRelation:
    "SELECT \(.columns | keys | join(", ")) FROM \(.name)"
;

## jq query generation
# helper function for jq codegen
def jqExprForColumns:
    if length == 1 then # use the column (single column)
        ".\(.[0])"
    else # or join column values with at-sign if there are more than one
        "\"\(map("\\(.\(.))") | join("@"))\""
    end
;
# jq code for turning json lines unloaded from database into Elasticsearch's _bulk API payload
def jqForBulkLoadingRelationIntoElasticsearch:
    (
        # taking the first group of columns referencing a @source relation
        [ sourceRelations |
          .byColumn | map(.name) | sort
        ][0]
    ) as $columnsForParent |
    "
    # index action/metadata
    {index:{ _id: \(keyColumns | map(.name) | sort | jqExprForColumns)\(
          if $columnsForParent == null then "" else
      ", _parent: \($columnsForParent | jqExprForColumns
       )" end) }},
    # followed by the actual document to index
    .
    " # TODO remove redundant @references columns
;

## Search frontend and Elasticsearch helpers
# type mapping
{
    # TODO byte
    # TODO short
    int: "integer",
    bigint: "long",
    # float
    # double
    text: "string",
    bool: "boolean"
    # TODO date
    # TODO binary
} as $toElasticsearchTypes |
def elasticsearchTypeForDDlogType:
    rtrimstr("[]") | # TODO handle nested arrays
    $toElasticsearchTypes[.] // .
;

# properties
def elasticsearchPropertiesForMappings:
    [(
        [.relation | columns]
        # except the columns referencing others
        - [.references[] | select(.graph) | .byColumn[]] | .[] |
        {
            key: .name,
            value: {
                type: .type | elasticsearchTypeForDDlogType,
                index: (
                    # only have @searchable columns broken into tokens
                    if isAnnotated(.name == "searchable")
                    then "analyzed"
                    else "not_analyzed"
                    end
                )
            }
        }
    ), (
        .references[] | select(.graph) | {
            key: .alias,
            value: {
                properties: .graph | elasticsearchPropertiesForMappings
            }
        }
    ), (
        .referencedBy[] | select(.graph) | {
            key: "\(.byRelation)_\(.alias)",
            value: {
                properties: .graph | elasticsearchPropertiesForMappings
            }
        }
    )] | from_entries
;

def elasticsearchMappingsForRelations:
    map({
        key: .name,
        value: relationSubgraphForSearchFromRelation | ({
            # generate a full mapping with all properties
            properties: elasticsearchPropertiesForMappings,
        } * (
            # _parent to the first @source relation
            [.relation | sourceRelations][0].relation |
            if . then { _parent: { type: . } } else {} end
        ))
    }) |
    from_entries
;

def searchFrontendSchema:
    [ relations | annotated([.name] | inside(["source", "extraction"])) |
    { key: .name, value: relationSubgraphForSearchFromRelation | {
              kind: (if .relation | isAnnotated(.name == "source") then "source" else "extraction" end),
        # add paths for nested fields
        searchable: [allNestedFields(annotated(.name == "searchable"))],
         navigable: [allNestedFields(annotated(.name == "navigable"))],
        # TODO presentation fields
            source: [
                .relation | sourceRelations |
                { type: .relation
                , fields: (.byColumn | map(.name))
                , alias: .alias
                }][0]
    } } ] | from_entries
;
