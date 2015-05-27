# named parameters given
export variable='has_spouse.is_true'
export mention_id='relation_id'
export words_column='description'
export doc_id_column=''
export features_layout='own_table'
export features_table='has_spouse_features'
export features_column='feature'
export candidate_id_column='relation_id'

: ${variable:?name of the variable, e.g., foo.bar where foo is the table name is bar is the column in the table} # required
: ${expectation_threshold:=0.9}  # the minimum value a mention's expectation should exceed to be considered as an extraction
: ${candidate_id_column:=mention_id}  # name of the column for the candidate key in variable's table
: ${words_column:=words}  # name of the column for the words of the mention in the variable's table
: ${doc_id_column:=doc_id}  # name of the column for the document id of a mention/extraction
: ${num_most_frequent_candidates:=100}  # number of most frequent candidate samples to report
export variable expectation_threshold candidate_id_column words_column doc_id_column num_most_frequent_candidates
