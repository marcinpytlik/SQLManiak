/*
    POC: Secure export without unconstrained delegation
    Stage 4 - CmdExec Proxy using the existing dedicated Credential

    Reuses:
      Credential: POC_SSIS_Export_Credential
      Identity  : SQLLAB\poc-ssis-export
*/

USE [msdb];
GO

SET NOCOUNT ON;

DECLARE @ProxyName sysname = N'POC_Export_CmdExec_Proxy';
DECLARE @CredentialName sysname = N'POC_SSIS_Export_Credential';
DECLARE @ProxyId int;
DECLARE @CmdExecSubsystemId int;

IF NOT EXISTS
(
    SELECT 1
    FROM master.sys.credentials
    WHERE name = @CredentialName
)
BEGIN
    THROW 56001, 'Required Credential POC_SSIS_Export_Credential was not found.', 1;
END;

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
         @description = N'POC CmdExec proxy for secure export to SMB using SQLLAB\poc-ssis-export.';
END
ELSE
BEGIN
    EXEC dbo.sp_update_proxy
         @proxy_name = @ProxyName,
         @credential_name = @CredentialName,
         @enabled = 1,
         @description = N'POC CmdExec proxy for secure export to SMB using SQLLAB\poc-ssis-export.';
END;

SELECT @ProxyId = proxy_id
FROM dbo.sysproxies
WHERE name = @ProxyName;

SELECT @CmdExecSubsystemId = subsystem_id
FROM dbo.syssubsystems
WHERE subsystem = N'CmdExec';

IF @CmdExecSubsystemId IS NULL
BEGIN
    THROW 56002, 'SQL Agent CmdExec subsystem was not found.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.sysproxysubsystem
    WHERE proxy_id = @ProxyId
      AND subsystem_id = @CmdExecSubsystemId
)
BEGIN
    EXEC dbo.sp_grant_proxy_to_subsystem
         @proxy_name = @ProxyName,
         @subsystem_name = N'CmdExec';
END;

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
WHERE p.name = @ProxyName;
GO
