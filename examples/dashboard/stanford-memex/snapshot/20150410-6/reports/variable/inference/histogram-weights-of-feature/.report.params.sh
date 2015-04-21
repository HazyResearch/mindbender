# named parameters given
export variable='rates.is_correct'

: ${variable:?name of the variable, e.g., foo.bar where foo is the table name is bar is the column in the table} # required
: ${expectation_threshold:=0.9}  # the minimum value a mention's expectation should exceed to be considered as an extraction
: ${candidate_id_column:=mention_id}  # name of the column for the candidate key in variable's table
: ${words_column:=words}  # name of the column for the words of the mention in the variable's table
: ${doc_id_column:=doc_id}  # name of the column for the document id of a mention/extraction
: ${num_top_extractions:=10}  # the number of most frequent extractions to enumerate
: ${num_histogram_bins:=20}  # number of bins to use in the histogram
: ${enable_freedman_diaconis_histogram:=false}  # whether to use Freedman-Diaconis rules for deciding bin width
: ${feature_weights_table:=dd_inference_result_variables_mapped_weights}  # name of the table holding learned weights for all features
export variable expectation_threshold candidate_id_column words_column doc_id_column num_top_extractions num_histogram_bins enable_freedman_diaconis_histogram feature_weights_table
