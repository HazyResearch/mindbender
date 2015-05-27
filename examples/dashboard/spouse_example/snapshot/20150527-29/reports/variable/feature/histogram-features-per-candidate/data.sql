
            SELECT num_features
                 , COUNT(candidate) AS num_candidates
              FROM (
                SELECT relation_id AS candidate
                     , COUNT(feature) AS num_features
                  FROM has_spouse_features
                 GROUP BY relation_id
              ) num_features_per_candidate
             GROUP BY num_features
             ORDER BY num_features ASC

