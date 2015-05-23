
    (
        SELECT CASE bin
               WHEN 0 THEN (SELECT MIN(weight)
                              FROM dd_inference_result_variables_mapped_weights
                             WHERE weight > 0)
               ELSE .33333556900815150000 * bin
               END                          AS weight_ge
             ,      .33333556900815150000 * (bin+1)  AS weight_lt
             ,      AVG(weight)             AS weight
             ,      COUNT(*)                AS num_features
          FROM (
            SELECT FLOOR(weight / .33333556900815150000) AS bin
                 , weight
              FROM dd_inference_result_variables_mapped_weights
             WHERE weight <> 0
          ) binned_weights
         GROUP BY bin
    ) UNION (
        SELECT 0        AS weight_ge
             , NULL     AS weight_lt
             , 0        AS weight
             , COUNT(*) AS num_features
          FROM dd_inference_result_variables_mapped_weights
         WHERE weight = 0
    )
    ORDER BY weight_ge
