/* 03_Reports.sql
   Raporty: Audit, PBM i korelacja zdarzeń
*/

/*** 1) Szybki raport z audytu ***/
DECLARE @AuditPath nvarchar(260) = N'E:\SQLAudit\*.sqlaudit';

SELECT TOP (200)
    event_time,
    server_principal_name AS kto,
    database_name,
    action_id,
    succeeded,
    statement
FROM sys.fn_get_audit_file(@AuditPath, DEFAULT, DEFAULT)
WHERE action_id IN ('AL','DR','CR') -- ALTER/DROP/CREATE
   OR statement LIKE '%ALTER DATABASE%'
ORDER BY event_time DESC;

/*** 2) Ostatnie naruszenia PBM ***/
SELECT TOP (200)
    h.execution_date,
    pol.name        AS policy_name,
    tgt.target_query_expression AS target,
    h.result        AS evaluation_result,
    det.exception_message
FROM msdb.dbo.syspolicy_policy_execution_history h
JOIN msdb.dbo.syspolicy_policies pol
  ON pol.policy_id = h.policy_id
LEFT JOIN msdb.dbo.syspolicy_policy_execution_history_details det
  ON det.history_id = h.history_id
LEFT JOIN msdb.dbo.syspolicy_target_set_levels tgt
  ON tgt.object_set_id = pol.object_set_id
WHERE pol.name = N'Policy_DB_Options_Compliance'
ORDER BY h.execution_date DESC;

/*** 3) Korelacja PBM <-> Audit (±15 min) ***/
;WITH AuditEvents AS (
    SELECT
        event_time,
        server_principal_name AS kto,
        database_name,
        statement
    FROM sys.fn_get_audit_file(@AuditPath, DEFAULT, DEFAULT)
    WHERE statement LIKE '%ALTER DATABASE%'
),
PbmViolations AS (
    SELECT
        h.execution_date,
        pol.name        AS policy_name,
        REPLACE(REPLACE(tgt.target_query_expression, '[', ''), ']', '') AS database_name
    FROM msdb.dbo.syspolicy_policy_execution_history h
    JOIN msdb.dbo.syspolicy_policies pol
      ON pol.policy_id = h.policy_id
    LEFT JOIN msdb.dbo.syspolicy_target_set_levels tgt
      ON tgt.object_set_id = pol.object_set_id
    WHERE pol.name = N'Policy_DB_Options_Compliance'
      AND h.result = 0 -- failed
)
SELECT
    v.execution_date   AS violation_time,
    v.policy_name,
    v.database_name,
    a.kto,
    a.statement
FROM PbmViolations v
LEFT JOIN AuditEvents a
  ON a.database_name = v.database_name
 AND a.event_time BETWEEN DATEADD(MINUTE, -15, v.execution_date)
                      AND DATEADD(MINUTE,  15, v.execution_date)
ORDER BY violation_time DESC;
