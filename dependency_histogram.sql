SELECT s.property, COUNT(distinct s.id) as qtd
FROM sentences s, dependencies d
WHERE  s.id = d.stc_id
GROUP BY s.property
ORDER BY qtd desc