# named parameters given
export variable='rates.is_correct'

: ${variable:?name of the variable, e.g., foo.bar where foo is the table name is bar is the column in the table} # required
: ${expectation_threshold:=0.9}  # the minimum value a mention's expectation should exceed to be considered as an extraction
: ${candidate_id_column:=mention_id}  # name of the column for the candidate key in variable's table
: ${words_column:=words}  # name of the column for the words of the mention in the variable's table
: ${doc_id_column:=doc_id}  # name of the column for the document id of a mention/extraction
: ${features_array_column:=features}  # name of the column in the variable table holding features as array
: ${features_table:=}  # name of the table holding one feature per row for the variable
: ${features_column:=}  # name of the column of the feature_table holding the feature id
: ${num_most_frequent_features:=100}  # the number of most frequent features to enumerate
export variable expectation_threshold candidate_id_column words_column doc_id_column features_array_column features_table features_column num_most_frequent_features
