-- scripts/04_per_query_hints.sql
USE CE_Lab;
GO
-- Wymuszenie CE na poziomie zapytania (bez zmiany compat level bazy)
-- 1) Legacy CE
SELECT COUNT(*) 
FROM dbo.CorrData
WHERE A = 1 AND B = 1
OPTION (QUERYTRACEON 9481); -- legacy CE

-- 2) Current CE
SELECT COUNT(*)
FROM dbo.CorrData
WHERE A = 1 AND B = 1
OPTION (QUERYTRACEON 2312); -- new CE (w nowszych buildach użyj QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_* hint)
