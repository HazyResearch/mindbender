
        SELECT words AS candidate, COUNT(*) AS count
        FROM gene_mentions
        GROUP BY words
        ORDER BY count DESC, words
        LIMIT 10


