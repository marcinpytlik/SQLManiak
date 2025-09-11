
PRINT '--- Lab 2: Memory Grant Feedback (with persistence in SQL 2022) ---';
SET NOCOUNT ON;
USE AQP_Lab;

DBCC FREEPROCCACHE WITH NO_INFOMSGS;
GO

-- 1) Pierwsza kompilacja/egzekucja (możliwy over/under‑grant)
SELECT grp, COUNT(*) AS c
INTO #t_mgf
FROM dbo.Skew
GROUP BY grp
ORDER BY c DESC;

DROP TABLE #t_mgf;
GO

-- 2) Kilka kolejnych uruchomień, aby feedback się utrwalił w QS
DECLARE @i int=0;
WHILE @i<5
BEGIN
  SELECT grp, COUNT(*) AS c
  FROM dbo.Skew
  GROUP BY grp
  OPTION (MAXDOP 0);
  SET @i+=1;
END
GO

-- 3) Weryfikacja feedbacku (MGF/CE/DOP zapisują się w QS)
SELECT TOP (50)
    qsq.query_id, qsp.plan_id, qspf.feedback_type_desc, qspf.feedback_state_desc, qspf.last_update
FROM sys.query_store_plan_feedback qspf
JOIN sys.query_store_plan  qsp ON qsp.plan_id  = qspf.plan_id
JOIN sys.query_store_query qsq ON qsq.query_id = qsp.query_id
ORDER BY qspf.last_update DESC;
