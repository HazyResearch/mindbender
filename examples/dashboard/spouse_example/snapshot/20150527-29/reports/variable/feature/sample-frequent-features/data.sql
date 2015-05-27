
            SELECT num_candidates
                 , feature
              FROM (
                SELECT feature AS feature
                     , COUNT(relation_id) AS num_candidates
                  FROM has_spouse_features
                 GROUP BY feature
              ) num_candidates_per_feature
             ORDER BY num_candidates DESC
             LIMIT 100
        
