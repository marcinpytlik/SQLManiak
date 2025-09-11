
PRINT '--- Lab 1: Parameter Sensitive Plan Optimization (PSP) ---';
SET NOCOUNT ON;
USE AQP_Lab;

-- Procedura celowo napisana tak, by wartości parametru dawały skrajnie różne rozkłady
IF OBJECT_ID('dbo.usp_FindByGroup','P') IS NOT NULL DROP PROCEDURE dbo.usp_FindByGroup;
GO
CREATE OR ALTER PROCEDURE dbo.usp_FindByGroup @grp int AS
BEGIN
  SET NOCOUNT ON;
  SELECT TOP (100000) *
  FROM dbo.Skew
  WHERE grp = @grp
  ORDER BY id DESC;
END
GO

-- Czyścimy cache i wykonujemy dwa biegi: "dużo wierszy" vs "mało wierszy"
DBCC FREEPROCCACHE WITH NO_INFOMSGS;
GO
EXEC dbo.usp_FindByGroup @grp = 1;     -- scenariusz dominujący (99%)
EXEC dbo.usp_FindByGroup @grp = 9999;  -- scenariusz rzadki (1%)
GO

-- Weryfikacja w Query Store: plan typu Dispatcher + warianty
SELECT qsq.query_id, qsp.plan_id, qsp.plan_type_desc, rs.count_executions, rs.avg_duration
FROM sys.query_store_query qsq
JOIN sys.query_store_plan  qsp ON qsp.query_id = qsq.query_id
JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qsp.plan_id
WHERE qsq.object_id = OBJECT_ID('dbo.usp_FindByGroup')
ORDER BY qsp.plan_type_desc, rs.avg_duration DESC;

-- Relacja parent <-> warianty PSP
SELECT *
FROM sys.query_store_query_variant
WHERE parent_query_id IN (SELECT qsq.query_id FROM sys.query_store_query qsq WHERE qsq.object_id = OBJECT_ID('dbo.usp_FindByGroup'));
