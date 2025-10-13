/* scripts/04_Flag_Risky_Steps.sql
   Heurystyki ryzyka: CmdExec/PowerShell/SSIS bez proxy, osieroceni właściciele, T‑SQL pod sysadmin. */
SET NOCOUNT ON;

;WITH JobBase AS (
    SELECT j.job_id,
           j.name AS job_name,
           SUSER_SNAME(j.owner_sid) AS job_owner,
           CASE WHEN IS_SRVROLEMEMBER('sysadmin', SUSER_SNAME(j.owner_sid)) = 1 THEN 1 ELSE 0 END AS owner_is_sysadmin
    FROM msdb.dbo.sysjobs AS j
),
StepDet AS (
    SELECT s.job_id,
           s.step_id,
           s.step_name,
           s.subsystem,
           s.proxy_id
    FROM msdb.dbo.sysjobsteps AS s
)
SELECT 
  b.job_name,
  b.job_owner,
  d.step_id,
  d.step_name,
  d.subsystem,
  CASE 
    WHEN d.subsystem IN ('CmdExec','CMDEXEC','PowerShell','SSIS','Dts') AND d.proxy_id IS NULL
         THEN 'RISK: non‑TSQL subsystem without proxy'
    WHEN d.subsystem IN ('TSQL','Transact-SQL') AND b.owner_is_sysadmin = 1
         THEN 'RISK: T-SQL runs as sysadmin (owner)'
    WHEN b.job_owner IS NULL
         THEN 'RISK: orphaned job owner (NULL)'
    ELSE 'OK'
  END AS risk_flag
FROM JobBase b
JOIN StepDet d ON d.job_id = b.job_id
ORDER BY CASE WHEN risk_flag='OK' THEN 1 ELSE 0 END, b.job_name, d.step_id;
