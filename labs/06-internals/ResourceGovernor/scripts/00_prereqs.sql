:setvar Info "Prereqs & sanity checks"
PRINT N'== $(Info) ==';

-- Enterprise info for IO governance
DECLARE @edition int = CAST(SERVERPROPERTY('EngineEdition') AS int);
IF @edition <> 3
BEGIN
    PRINT N'INFO: I/O governance (MIN/MAX_IOPS_PER_VOLUME) wymaga Enterprise. CPU/memory działa niezależnie.';
END

-- SQL Server version check for CAP_CPU_PERCENT (2019+ recommended)
DECLARE @prodver nvarchar(128) = CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128));
PRINT N'Version: ' + @prodver;

-- Enable RG if needed
IF (SELECT is_enabled FROM sys.resource_governor_configuration) = 0
BEGIN
    PRINT N'Enabling Resource Governor...';
    ALTER RESOURCE GOVERNOR RECONFIGURE;
END
GO
"
