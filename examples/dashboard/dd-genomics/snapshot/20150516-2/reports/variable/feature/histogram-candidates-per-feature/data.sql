
            SELECT num_candidates
                 , COUNT(feature) AS num_features
              FROM (
                SELECT feature AS feature
                     , COUNT(mention_id) AS num_candidates
                  FROM pheno_features
                 GROUP BY feature
              ) num_candidates_per_feature
             GROUP BY num_candidates
             ORDER BY num_candidates ASC

