-- scripts/03_find_and_force_plan.sql
-- Znajdź query_id i plan_id dla zapytania, następnie wymuś „dobry” plan.

USE QS_Lab;
GO

-- Identyfikujemy zapytanie po tekście (upraszczamy dla labu)
DECLARE @query_text NVARCHAR(4000) = N'SELECT COUNT(*) FROM dbo.SalesSkew WHERE Region = @r';

SELECT TOP (10)
    qsq.query_id, qsp.plan_id, qsp.force_failure_count, qsp.last_force_failure_reason_desc,
    rs.avg_duration, rs.avg_cpu_time, rs.avg_logical_io_reads
FROM sys.query_store_query_text AS qt
JOIN sys.query_store_query AS qsq ON qsq.query_text_id = qt.query_text_id
JOIN sys.query_store_plan AS qsp ON qsp.query_id = qsq.query_id
JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = qsp.plan_id
WHERE qt.query_sql_text LIKE '%SalesSkew WHERE Region = @r%'
ORDER BY rs.avg_duration DESC;

-- Załóżmy, że niższa avg_duration to „dobry plan” → wymuś ten plan:
-- Podmień wartości poniżej po odczytaniu z SELECTa
-- EXEC sys.sp_query_store_force_plan @query_id = <q>, @plan_id = <p>;
-- Sprawdź status:
-- SELECT query_id, plan_id, is_forced_plan, force_failure_count FROM sys.query_store_plan WHERE query_id = <q>;
