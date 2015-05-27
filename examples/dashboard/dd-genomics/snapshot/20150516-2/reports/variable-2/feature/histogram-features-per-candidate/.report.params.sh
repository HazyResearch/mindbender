# named parameters given
export variable='gene_mentions.is_correct'
export features_layout='own_table'
export features_table='gene_features'
export features_column='feature'

: ${variable:?name of the variable, e.g., foo.bar where foo is the table name is bar is the column in the table} # required
: ${expectation_threshold:=0.9}  # the minimum value a mention's expectation should exceed to be considered as an extraction
: ${candidate_id_column:=mention_id}  # name of the column for the candidate key in variable's table
: ${words_column:=words}  # name of the column for the words of the mention in the variable's table
: ${doc_id_column:=doc_id}  # name of the column for the document id of a mention/extraction
: ${features_layout:=array_column}  # how features are stored in the database: must be either 'array_column' or 'own_table'
: ${features_column:=features}  # name of the column of the features_table holding the feature or the column of the variable table holding features array
: ${features_table:=}  # name of the table holding one feature per row for the variable, necessary when features_layout=own_table
export variable expectation_threshold candidate_id_column words_column doc_id_column features_layout features_column features_table
