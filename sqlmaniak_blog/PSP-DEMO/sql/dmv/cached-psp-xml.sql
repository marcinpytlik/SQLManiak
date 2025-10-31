
-- sql/dmv/cached-psp-xml.sql
-- Szuka wpisów PSP w planach XML w cache

SELECT TOP (50)
    DB_NAME(t.dbid) AS DbName,
    cp.objtype,
    cp.usecounts,
    qp.query_plan
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
CROSS APPLY (SELECT COALESCE(CONVERT(INT, qp.dbid), 0) AS dbid) t
WHERE qp.query_plan LIKE '%ParameterSensitivePlan%'
ORDER BY cp.usecounts DESC;
