# named parameters given

: ${num_histogram_bins:=20}  # number of bins to use in the histogram
: ${enable_freedman_diaconis_histogram:=false}  # whether to use Freedman-Diaconis rules for deciding bin width
: ${feature_weights_table:=dd_inference_result_variables_mapped_weights}  # name of the table holding learned weights for all features
export num_histogram_bins enable_freedman_diaconis_histogram feature_weights_table
