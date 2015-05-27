
    (
        SELECT CASE bin
               WHEN 0 THEN (SELECT MIN(weight)
                              FROM dd_inference_result_variables_mapped_weights
                             WHERE weight > 0)
               ELSE .07944061000000000000 * bin
               END                         AS weight_ge
             ,      .07944061000000000000 * (bin+1) AS weight_lt
             ,      COUNT(*)               AS num_features
          FROM (
            SELECT FLOOR(weight / .07944061000000000000) AS bin
              FROM dd_inference_result_variables_mapped_weights
             WHERE weight <> 0
          ) binned_weights
         GROUP BY bin
    ) UNION (
        SELECT 0        AS weight_ge
             , 0        AS weight_lt
             , COUNT(*) AS num_features
          FROM dd_inference_result_variables_mapped_weights
         WHERE weight = 0
    )
    ORDER BY weight_ge
