/* scripts/02_JobSteps_RunAs_Detail.sql
   Raport szczegółowy per krok: rzeczywisty kontekst uruchomienia (OS + SQL) */
SET NOCOUNT ON;

;WITH AgentSvc AS (
    SELECT service_account AS agent_service_account
    FROM sys.dm_server_services
    WHERE servicename LIKE 'SQL Server Agent (%'
),
JobBase AS (
    SELECT j.job_id,
           j.name                   AS job_name,
           SUSER_SNAME(j.owner_sid) AS job_owner,
           CASE WHEN IS_SRVROLEMEMBER('sysadmin', SUSER_SNAME(j.owner_sid)) = 1 THEN 1 ELSE 0 END AS owner_is_sysadmin
    FROM msdb.dbo.sysjobs AS j
),
StepDet AS (
    SELECT s.job_id,
           s.step_id,
           s.step_name,
           s.subsystem,
           s.proxy_id,
           p.name AS proxy_name,
           c.name AS credential_name,
           c.identity_name AS proxy_identity
    FROM msdb.dbo.sysjobsteps AS s
    LEFT JOIN msdb.dbo.sysproxies AS p       ON p.proxy_id      = s.proxy_id
    LEFT JOIN sys.credentials AS c           ON c.credential_id = p.credential_id
)
SELECT b.job_name,
       b.job_owner,
       b.owner_is_sysadmin,
       d.step_id,
       d.step_name,
       d.subsystem,
       CASE WHEN d.proxy_id IS NOT NULL THEN d.proxy_identity
            ELSE a.agent_service_account
       END AS os_run_as,
       CASE 
         WHEN d.subsystem IN ('TSQL','Transact-SQL') THEN 
             CASE WHEN b.owner_is_sysadmin = 1 THEN 'T-SQL: sysadmin (właściciel)'
                  ELSE 'T-SQL: uprawnienia właściciela joba'
             END
         ELSE 'Poziom OS: konto proxy lub Agent service account'
       END AS sql_permissions_context,
       d.proxy_name,
       d.credential_name
FROM JobBase b
JOIN StepDet d ON d.job_id = b.job_id
CROSS JOIN AgentSvc a
ORDER BY b.job_name, d.step_id;
