
        SELECT words, COUNT(*) AS count
        FROM gene_mentions_is_correct_inference
        WHERE expectation > 0.9
        GROUP BY words
        ORDER BY count DESC, words
        LIMIT 100


