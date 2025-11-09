-- 6) Alerty replikacyjne w msdb (jeśli używasz)
SET NOCOUNT ON;
SELECT * 
FROM msdb.dbo.sysalerts 
WHERE category_id IN (SELECT category_id FROM msdb.dbo.syscategories WHERE name LIKE 'REPLICATION%')
ORDER BY name;

SELECT TOP (200) * 
FROM msdb.dbo.sysreplicationalerts
ORDER BY alert_time DESC;
