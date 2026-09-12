/*
    POC: Secure SSIS Export without unconstrained delegation
    Stage 3 - SQL Agent Proxy for SSIS only

    Prerequisite:
      Credential: POC_SSIS_Export_Credential
      Identity  : SQLLAB\poc-ssis-export
*/

USE [msdb];
GO

DECLARE @ProxyName sysname = N'POC_SSIS_Export_Proxy';
DECLARE @CredentialName sysname = N'POC_SSIS_Export_Credential';

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.sysproxies
    WHERE name = @ProxyName
)
BEGIN
    EXEC dbo.sp_add_proxy
         @proxy_name = @ProxyName,
         @credential_name = @CredentialName,
         @enabled = 1,
         @description = N'POC proxy for secure SSIS export to network share.';
END
ELSE
BEGIN
    EXEC dbo.sp_update_proxy
         @proxy_name = @ProxyName,
         @credential_name = @CredentialName,
         @enabled = 1,
         @description = N'POC proxy for secure SSIS export to network share.';
END;
GO

DECLARE @ProxyId int =
(
    SELECT proxy_id
    FROM dbo.sysproxies
    WHERE name = N'POC_SSIS_Export_Proxy'
);

DECLARE @SsisSubsystemId int =
(
    SELECT subsystem_id
    FROM dbo.syssubsystems
    WHERE subsystem = N'SSIS'
);

IF @SsisSubsystemId IS NULL
BEGIN
    THROW 52001, 'SQL Agent SSIS subsystem was not found on this instance.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.sysproxysubsystem
    WHERE proxy_id = @ProxyId
      AND subsystem_id = @SsisSubsystemId
)
BEGIN
    EXEC dbo.sp_grant_proxy_to_subsystem
         @proxy_name = N'POC_SSIS_Export_Proxy',
         @subsystem_name = N'SSIS';
END;
GO

SELECT
    p.name AS ProxyName,
    p.enabled,
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
