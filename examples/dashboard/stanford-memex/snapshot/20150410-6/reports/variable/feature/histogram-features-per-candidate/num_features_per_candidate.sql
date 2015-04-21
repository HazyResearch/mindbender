
            SELECT num_features
                 , COUNT(candidate) AS num_candidates
              FROM (
                SELECT mention_id AS candidate
                     , ( ARRAY_UPPER(features,1)
                       - ARRAY_LOWER(features,1) ) AS num_features
                  FROM rates
              ) num_features_per_candidate
             GROUP BY num_features
             ORDER BY num_features ASC
        
