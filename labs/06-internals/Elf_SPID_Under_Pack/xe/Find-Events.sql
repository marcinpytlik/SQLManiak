/* XE Helper — znajdź eventy (różnice między wersjami SQL) */

-- Szukaj eventów po słowie kluczowym
DECLARE @keyword sysname = N'checkpoint';  -- podmień np. na 'ghost', 'resource', 'hadr', 'xtp'

SELECT o.name AS event_name,
       o.description
FROM sys.dm_xe_objects AS o
WHERE o.object_type = 'event'
  AND (o.name LIKE N'%' + @keyword + N'%' OR o.description LIKE N'%' + @keyword + N'%')
ORDER BY o.name;
