DELETE d
FROM sentences s, dependencies d
WHERE  s.id = d.stc_id and s.property like '%riverMouth'
