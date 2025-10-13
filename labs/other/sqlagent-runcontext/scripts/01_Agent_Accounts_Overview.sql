/* scripts/01_Agent_Accounts_Overview.sql
   Zbiorczy przegląd: konto usługi Agenta + właściciel joba + lista proxy użytych w krokach */
SET NOCOUNT ON;

-- 1) Konto usługi SQL Server Agent
SELECT servicename, startup_type_desc, status_desc, service_account AS agent_service_account
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server Agent (%';

-- 2) Zestawienie per job (owner + proxy list)
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
),
AggProxy AS (
    SELECT d.job_id,
           STUFF((SELECT DISTINCT ',' + ISNULL(d2.proxy_name,'(brak)')
                  FROM StepDet d2 WHERE d2.job_id = d.job_id
                  FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,1,'') AS proxies_used
    FROM StepDet d
    GROUP BY d.job_id
)
SELECT b.job_name,
       b.job_owner,
       b.owner_is_sysadmin,
       a.agent_service_account,
       ISNULL(ap.proxies_used,'(brak)') AS proxies_used
FROM JobBase b
CROSS JOIN AgentSvc a
LEFT JOIN AggProxy ap ON ap.job_id = b.job_id
ORDER BY b.job_name;
