/* Detect-PlanCache-Duplicates.sql
   Wykrywanie duplikatów planów/ad-hoc po query_hash oraz „śmieci” (execution_count = 1).
   Uwaga: query_hash grupuje logicznie podobne zapytania niezależnie od wartości parametrów.
*/
SET NOCOUNT ON;

;WITH Q AS
(
    SELECT
        qs.query_hash,
        COUNT(*)                         AS PlansPerHash,
        SUM(qs.execution_count)          AS TotalExecs,
        SUM(qs.total_elapsed_time)       AS TotalElapsed,
        MIN(qs.creation_time)            AS FirstSeen,
        MAX(qs.last_execution_time)      AS LastSeen
    FROM sys.dm_exec_query_stats AS qs
    GROUP BY qs.query_hash
)
SELECT TOP (50)
    Q.query_hash,
    Q.PlansPerHash,
    Q.TotalExecs,
    Q.TotalElapsed / 1000 AS TotalElapsedMs,
    Q.FirstSeen,
    Q.LastSeen,
    t.text AS SampleSql
FROM Q
CROSS APPLY
(
    SELECT TOP (1) t.text
    FROM sys.dm_exec_query_stats qs2
    CROSS APPLY sys.dm_exec_sql_text(qs2.sql_handle) AS t
    WHERE qs2.query_hash = Q.query_hash
    ORDER BY qs2.execution_count DESC
) AS T
WHERE Q.PlansPerHash > 1 -- potencjalne duplikaty
   OR (Q.TotalExecs = 1) -- „śmieci” jednorazowe
ORDER BY Q.PlansPerHash DESC, Q.TotalExecs ASC;
