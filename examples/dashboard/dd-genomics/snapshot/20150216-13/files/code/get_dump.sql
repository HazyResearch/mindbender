COPY (
	SELECT 
		  t2.relation_id
		, t0.entity 
		, array_to_string(t0.words, ' ')
		, t1.entity
		, t0.doc_id
		, t0.sent_id
	FROM
		  gene_hpoterm_relations_is_correct_inference t2
	LEFT JOIN gene_mentions t0 ON t2.mention_id_1 = t0.mention_id
	LEFT JOIN hpoterm_mentions t1 ON t2.mention_id_2 = t1.mention_id
	WHERE
		t2.expectation > 0.9
) TO STDOUT
;

