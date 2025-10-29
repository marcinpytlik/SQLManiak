
-- sql/dmv/qs-variants.sql
-- Wariantuje plany PSP (Query Store)

USE PSP_Demo;
GO

SELECT qsq.query_id,
       qsp.plan_id,
       qsp.is_parameter_sensitive_plan,
       qsp.last_compile_start_time,
       qsp.last_execution_time,
       qsp.engine_version
FROM sys.query_store_plan AS qsp
JOIN sys.query_store_query AS qsq ON qsq.query_id = qsp.query_id
WHERE qsq.object_id = OBJECT_ID('dbo.GetOrdersByCustomer')
ORDER BY qsp.last_execution_time DESC;

-- Zlicz warianty dla danego query_id
SELECT qsq.query_id,
       COUNT(DISTINCT qsp.plan_id) AS Variants
FROM sys.query_store_plan AS qsp
JOIN sys.query_store_query AS qsq ON qsq.query_id = qsp.query_id
WHERE qsq.object_id = OBJECT_ID('dbo.GetOrdersByCustomer')
GROUP BY qsq.query_id
HAVING COUNT(DISTINCT qsp.plan_id) > 1;
