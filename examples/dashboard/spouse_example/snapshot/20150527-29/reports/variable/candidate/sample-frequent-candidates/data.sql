
        SELECT description AS candidate, COUNT(*) AS count
        FROM has_spouse
        GROUP BY description
        ORDER BY count DESC, description
        LIMIT 100


