
            SELECT num_candidates
                 , COUNT(feature) AS num_features
              FROM (
                SELECT feature
                     , COUNT(candidate) AS num_candidates
                  FROM (
                    SELECT UNNEST(features) feature
                         , mention_id AS candidate
                      FROM locations
                  ) features
                 GROUP BY feature
              ) num_candidates_per_feature
             GROUP BY num_candidates
             ORDER BY num_candidates ASC
        
