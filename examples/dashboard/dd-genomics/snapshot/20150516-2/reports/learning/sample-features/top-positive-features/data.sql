-- Top 50 Positively Weighted Features
 SELECT weight, description
   FROM dd_inference_result_variables_mapped_weights
  ORDER BY weight DESC
  LIMIT 50
