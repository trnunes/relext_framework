SELECT s.property, COUNT(sp.stc_id)
FROM sentences s, sentence_paths sp
where s.id = sp.stc_id
GROUP BY s.property
ORDER BY COUNT(sp.stc_id) desc