:setvar DbName "TwojaBaza"
:setvar AdGroupLab "DOMENA\\RG_LAB_TwojaBaza"
:setvar AdGroupProd "DOMENA\\RG_PROD_TwojaBaza"
:setvar AppNameLabPattern "%LAB%"
:setvar AppNameProdPattern "%PROD%"

:setvar Pool_Lab "pool_lab_noisy"
:setvar Group_Lab "wg_lab_noisy"
:setvar Pool_Pro "pool_prod_friendly"
:setvar Group_Pro "wg_prod_friendly"

-- Preset LAB
:setvar Lab_CapCpu 30
:setvar Lab_MaxDop 1
:setvar Lab_ReqMaxMemGrantPct 10
:setvar Lab_ReqMinMemGrantPct 0
:setvar Lab_ReqGrantTimeoutSec 0
:setvar Lab_GroupMaxRequests 0
:setvar Lab_Importance "LOW"
:setvar Lab_MaxIOPS 800
:setvar Lab_MinIOPS 0

-- Preset PROD
:setvar Pro_CapCpu 30
:setvar Pro_MaxDop 2
:setvar Pro_ReqMaxMemGrantPct 15
:setvar Pro_ReqMinMemGrantPct 0
:setvar Pro_ReqGrantTimeoutSec 0
:setvar Pro_GroupMaxRequests 0
:setvar Pro_Importance "LOW"
:setvar Pro_MaxIOPS 1500
:setvar Pro_MinIOPS 300

USE master;
GO

/* 1) Resource pools with CPU + I/O caps */
DECLARE @sql nvarchar(max);

-- LAB pool
IF NOT EXISTS (SELECT 1 FROM sys.resource_governor_resource_pools WHERE name = N'$(Pool_Lab)')
    SET @sql = N'CREATE RESOURCE POOL ' + QUOTENAME(N'$(Pool_Lab)')
             + N' WITH (CAP_CPU_PERCENT = $(Lab_CapCpu), MAX_IOPS_PER_VOLUME = $(Lab_MaxIOPS), MIN_IOPS_PER_VOLUME = $(Lab_MinIOPS))';
ELSE
    SET @sql = N'ALTER RESOURCE POOL ' + QUOTENAME(N'$(Pool_Lab)')
             + N' WITH (CAP_CPU_PERCENT = $(Lab_CapCpu), MAX_IOPS_PER_VOLUME = $(Lab_MaxIOPS), MIN_IOPS_PER_VOLUME = $(Lab_MinIOPS))';
EXEC sys.sp_executesql @sql;

-- PROD pool
IF NOT EXISTS (SELECT 1 FROM sys.resource_governor_resource_pools WHERE name = N'$(Pool_Pro)')
    SET @sql = N'CREATE RESOURCE POOL ' + QUOTENAME(N'$(Pool_Pro)')
             + N' WITH (CAP_CPU_PERCENT = $(Pro_CapCpu), MAX_IOPS_PER_VOLUME = $(Pro_MaxIOPS), MIN_IOPS_PER_VOLUME = $(Pro_MinIOPS))';
ELSE
    SET @sql = N'ALTER RESOURCE POOL ' + QUOTENAME(N'$(Pool_Pro)')
             + N' WITH (CAP_CPU_PERCENT = $(Pro_CapCpu), MAX_IOPS_PER_VOLUME = $(Pro_MaxIOPS), MIN_IOPS_PER_VOLUME = $(Pro_MinIOPS))';
EXEC sys.sp_executesql @sql;
GO

/* 2) Workload groups */
DECLARE @sql2 nvarchar(max);

-- LAB group
IF NOT EXISTS (SELECT 1 FROM sys.resource_governor_workload_groups WHERE name = N'$(Group_Lab)')
    SET @sql2 = N'CREATE WORKLOAD GROUP ' + QUOTENAME(N'$(Group_Lab)')
              + N' WITH ('
              + N'  IMPORTANCE = $(Lab_Importance),'
              + N'  MAX_DOP = $(Lab_MaxDop),'
              + N'  REQUEST_MAX_MEMORY_GRANT_PERCENT = $(Lab_ReqMaxMemGrantPct),'
              + N'  REQUEST_MIN_MEMORY_GRANT_PERCENT = $(Lab_ReqMinMemGrantPct),'
              + N'  REQUEST_MEMORY_GRANT_TIMEOUT_SEC = $(Lab_ReqGrantTimeoutSec),'
              + N'  GROUP_MAX_REQUESTS = $(Lab_GroupMaxRequests)'
              + N') USING ' + QUOTENAME(N'$(Pool_Lab)');
ELSE
    SET @sql2 = N'ALTER WORKLOAD GROUP ' + QUOTENAME(N'$(Group_Lab)')
              + N' WITH ('
              + N'  IMPORTANCE = $(Lab_Importance),'
              + N'  MAX_DOP = $(Lab_MaxDop),'
              + N'  REQUEST_MAX_MEMORY_GRANT_PERCENT = $(Lab_ReqMaxMemGrantPct),'
              + N'  REQUEST_MIN_MEMORY_GRANT_PERCENT = $(Lab_ReqMinMemGrantPct),'
              + N'  REQUEST_MEMORY_GRANT_TIMEOUT_SEC = $(Lab_ReqGrantTimeoutSec),'
              + N'  GROUP_MAX_REQUESTS = $(Lab_GroupMaxRequests)'
              + N')';
EXEC sys.sp_executesql @sql2;

-- PROD group
IF NOT EXISTS (SELECT 1 FROM sys.resource_governor_workload_groups WHERE name = N'$(Group_Pro)')
    SET @sql2 = N'CREATE WORKLOAD GROUP ' + QUOTENAME(N'$(Group_Pro)')
              + N' WITH ('
              + N'  IMPORTANCE = $(Pro_Importance),'
              + N'  MAX_DOP = $(Pro_MaxDop),'
              + N'  REQUEST_MAX_MEMORY_GRANT_PERCENT = $(Pro_ReqMaxMemGrantPct),'
              + N'  REQUEST_MIN_MEMORY_GRANT_PERCENT = $(Pro_ReqMinMemGrantPct),'
              + N'  REQUEST_MEMORY_GRANT_TIMEOUT_SEC = $(Pro_ReqGrantTimeoutSec),'
              + N'  GROUP_MAX_REQUESTS = $(Pro_GroupMaxRequests)'
              + N') USING ' + QUOTENAME(N'$(Pool_Pro)');
ELSE
    SET @sql2 = N'ALTER WORKLOAD GROUP ' + QUOTENAME(N'$(Group_Pro)')
              + N' WITH ('
              + N'  IMPORTANCE = $(Pro_Importance),'
              + N'  MAX_DOP = $(Pro_MaxDop),'
              + N'  REQUEST_MAX_MEMORY_GRANT_PERCENT = $(Pro_ReqMaxMemGrantPct),'
              + N'  REQUEST_MIN_MEMORY_GRANT_PERCENT = $(Pro_ReqMinMemGrantPct),'
              + N'  REQUEST_MEMORY_GRANT_TIMEOUT_SEC = $(Pro_ReqGrantTimeoutSec),'
              + N'  GROUP_MAX_REQUESTS = $(Pro_GroupMaxRequests)'
              + N')';
EXEC sys.sp_executesql @sql2;

ALTER RESOURCE GOVERNOR RECONFIGURE;
GO

/* 3) Classifier: AD first, fallback on Application Name. Requires default DB = $(DbName) */
IF OBJECT_ID('master.dbo.ufn_rg_classifier', 'FN') IS NOT NULL
    DROP FUNCTION master.dbo.ufn_rg_classifier;
GO

CREATE FUNCTION master.dbo.ufn_rg_classifier()
RETURNS sysname
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @ret sysname = NULL;

    DECLARE @DbName     sysname       = N'$(DbName)';
    DECLARE @AdLab      sysname       = N'$(AdGroupLab)';
    DECLARE @AdProd     sysname       = N'$(AdGroupProd)';
    DECLARE @AppLabPat  nvarchar(100) = N'$(AppNameLabPattern)';
    DECLARE @AppProPat  nvarchar(100) = N'$(AppNameProdPattern)';
    DECLARE @GroupLab   sysname       = N'$(Group_Lab)';
    DECLARE @GroupPro   sysname       = N'$(Group_Pro)';
    
    IF ORIGINAL_LOGIN() IS NOT NULL AND DB_NAME() = @DbName
    BEGIN
        IF IS_MEMBER(@AdLab) = 1
            RETURN @GroupLab;
        IF IS_MEMBER(@AdProd) = 1
            RETURN @GroupPro;
    END

    IF DB_NAME() = @DbName
    BEGIN
        DECLARE @app nvarchar(128) = APP_NAME();
        IF @app IS NOT NULL
        BEGIN
            IF @app LIKE @AppLabPat
                RETURN @GroupLab;
            IF @app LIKE @AppProPat
                RETURN @GroupPro;
        END
    END

    RETURN @ret; -- NULL => default group
END
GO

ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = master.dbo.ufn_rg_classifier);
ALTER RESOURCE GOVERNOR RECONFIGURE;
GO
