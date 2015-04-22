
            SELECT num_candidates
                 , feature
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
             ORDER BY num_candidates DESC
             LIMIT 100
        
