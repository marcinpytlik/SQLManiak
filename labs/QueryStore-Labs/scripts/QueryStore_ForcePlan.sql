USE [AdventureWorks2022];
GO
DECLARE @query_id BIGINT = 42, @plan_id BIGINT = 7;
EXEC sp_query_store_force_plan @query_id = @query_id, @plan_id = @plan_id;

SELECT query_id, plan_id, is_forced_plan
FROM sys.query_store_plan
WHERE is_forced_plan = 1;
