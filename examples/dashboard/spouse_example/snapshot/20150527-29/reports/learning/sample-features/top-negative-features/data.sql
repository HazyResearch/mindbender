-- Top 10 Negatively Weighted Features
 SELECT weight, description
   FROM dd_inference_result_variables_mapped_weights
  ORDER BY weight ASC
  LIMIT 10
