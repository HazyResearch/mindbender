
            SELECT num_features
                 , COUNT(candidate) AS num_candidates
              FROM (
                SELECT mention_id AS candidate
                     , COUNT(feature) AS num_features
                  FROM gene_features
                 GROUP BY mention_id
              ) num_features_per_candidate
             GROUP BY num_features
             ORDER BY num_features ASC

