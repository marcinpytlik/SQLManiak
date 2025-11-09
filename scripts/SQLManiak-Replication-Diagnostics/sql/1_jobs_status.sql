-- 1) Ostatnie statusy jobów replikacyjnych (Snapshot/LogReader/Distribution/Merge)
-- Uruchom w msdb kontekst nie jest wymagany.
SET NOCOUNT ON;

SELECT 
  j.name AS JobName,
  CASE h.run_status 
       WHEN 0 THEN 'Failed' WHEN 1 THEN 'Succeeded' WHEN 2 THEN 'Retry'
       WHEN 3 THEN 'Canceled' WHEN 4 THEN 'In Progress' END AS LastStatus,
  CONVERT(datetime, CONCAT(
     STUFF(STUFF(REPLICATE('0',6-LEN(h.run_date))+CAST(h.run_date AS varchar(8)),5,0,'-'),8,0,'-'),' ',
     STUFF(STUFF(REPLICATE('0',6-LEN(h.run_time))+CAST(h.run_time AS varchar(6)),3,0,':'),6,0,':')
  )) AS LastRunDateTime,
  h.message
FROM msdb.dbo.sysjobs j
OUTER APPLY (
  SELECT TOP(1) h.*
  FROM msdb.dbo.sysjobhistory h
  WHERE h.job_id = j.job_id AND h.step_id = 0
  ORDER BY h.instance_id DESC
) h
WHERE j.name LIKE '%Snapshot Agent%' 
   OR j.name LIKE '%Log Reader Agent%' 
   OR j.name LIKE '%Distribution Agent%' 
   OR j.name LIKE '%Merge Agent%'
ORDER BY LastRunDateTime DESC;
