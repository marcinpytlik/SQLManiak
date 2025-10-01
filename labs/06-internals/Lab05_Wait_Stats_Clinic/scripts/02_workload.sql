-- scripts/02_workload.sql
-- Prosty workload generujący różne waity.
SET NOCOUNT ON;

-- 1) CPU / Parallelism
;WITH n AS (SELECT TOP (2000000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn FROM sys.all_objects a CROSS JOIN sys.all_objects b)
SELECT SUM(CHECKSUM(n.rn)) 
FROM n AS n1
JOIN n AS n2 ON n2.rn % 17 = n1.rn % 17
OPTION (MAXDOP 8);

-- 2) I/O: duży sort do tempdb
SELECT TOP (200000) * 
INTO #tmp_ws
FROM sys.objects o1 CROSS JOIN sys.columns c1;

CREATE INDEX IX ON #tmp_ws (name);
DROP TABLE #tmp_ws;
