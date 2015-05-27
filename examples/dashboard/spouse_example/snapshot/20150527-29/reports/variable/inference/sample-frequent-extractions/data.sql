
        SELECT description, COUNT(*) AS count
        FROM has_spouse_is_true_inference
        WHERE expectation > 0.9
        GROUP BY description
        ORDER BY count DESC, description
        LIMIT 100


