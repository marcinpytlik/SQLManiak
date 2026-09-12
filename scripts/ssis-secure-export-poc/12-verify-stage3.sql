/*
    POC: Secure SSIS Export without unconstrained delegation
    Stage 3 - verification
*/

USE [master];
GO

SELECT
    c.name AS CredentialName,
    c.credential_identity,
    c.create_date,
    c.modify_date
FROM sys.credentials AS c
WHERE c.name = N'POC_SSIS_Export_Credential';
GO

USE [msdb];
GO

SELECT
    p.name AS ProxyName,
    p.enabled AS ProxyEnabled,
    c.name AS CredentialName,
    c.credential_identity,
    s.subsystem AS GrantedSubsystem
FROM dbo.sysproxies AS p
JOIN master.sys.credentials AS c
    ON c.credential_id = p.credential_id
LEFT JOIN dbo.sysproxysubsystem AS ps
    ON ps.proxy_id = p.proxy_id
LEFT JOIN dbo.syssubsystems AS s
    ON s.subsystem_id = ps.subsystem_id
WHERE p.name = N'POC_SSIS_Export_Proxy';
GO

SELECT
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.sysproxies AS p
        JOIN master.sys.credentials AS c
            ON c.credential_id = p.credential_id
        JOIN dbo.sysproxysubsystem AS ps
            ON ps.proxy_id = p.proxy_id
        JOIN dbo.syssubsystems AS s
            ON s.subsystem_id = ps.subsystem_id
        WHERE p.name = N'POC_SSIS_Export_Proxy'
          AND p.enabled = 1
          AND c.name = N'POC_SSIS_Export_Credential'
          AND c.credential_identity = N'SQLLAB\poc-ssis-export'
          AND s.subsystem = N'SSIS'
    ) THEN 1 ELSE 0 END AS Stage3SqlAgentConfigurationOK;
GO
