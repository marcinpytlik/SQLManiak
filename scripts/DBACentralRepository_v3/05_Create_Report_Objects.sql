USE DBACentralRepository;
GO

CREATE OR ALTER VIEW report.vCurrentInstances
AS
SELECT
    I.InstanceId,I.ServerInstance,E.EnvironmentCode,E.EnvironmentName,I.Description,
    I.MachineName,I.ServerName,I.InstanceName,I.ProductVersion,I.ProductLevel,
    I.Edition,I.ProductMajorVersion,I.IsClustered,I.IsHadrEnabled,I.IsReachable,
    I.LastSeenAt,I.LastError
FROM dbo.Instance I
LEFT JOIN dbo.Environment E ON E.EnvironmentId=I.EnvironmentId;
GO

CREATE OR ALTER VIEW report.vCurrentJobs
AS
WITH X AS
(
    SELECT J.*,
           ROW_NUMBER() OVER
           (
               PARTITION BY InstanceId,JobId
               ORDER BY CapturedAt DESC,JobSnapshotId DESC
           ) rn
    FROM job.JobSnapshot J
)
SELECT I.ServerInstance,E.EnvironmentCode,X.*
FROM X
JOIN dbo.Instance I ON I.InstanceId=X.InstanceId
LEFT JOIN dbo.Environment E ON E.EnvironmentId=I.EnvironmentId
WHERE rn=1;
GO

CREATE OR ALTER VIEW report.vCurrentDatabases
AS
WITH X AS
(
    SELECT D.*,
           ROW_NUMBER() OVER
           (
               PARTITION BY InstanceId,DatabaseName
               ORDER BY CapturedAt DESC,DatabaseSnapshotId DESC
           ) rn
    FROM db.DatabaseSnapshot D
)
SELECT I.ServerInstance,E.EnvironmentCode,X.*
FROM X
JOIN dbo.Instance I ON I.InstanceId=X.InstanceId
LEFT JOIN dbo.Environment E ON E.EnvironmentId=I.EnvironmentId
WHERE rn=1;
GO

CREATE OR ALTER VIEW report.vCurrentVolumes
AS
WITH X AS
(
    SELECT V.*,
           ROW_NUMBER() OVER
           (
               PARTITION BY InstanceId,VolumeMountPoint
               ORDER BY CapturedAt DESC,VolumeSnapshotId DESC
           ) rn
    FROM capacity.VolumeSnapshot V
)
SELECT I.ServerInstance,E.EnvironmentCode,X.*
FROM X
JOIN dbo.Instance I ON I.InstanceId=X.InstanceId
LEFT JOIN dbo.Environment E ON E.EnvironmentId=I.EnvironmentId
WHERE rn=1;
GO

CREATE OR ALTER VIEW report.vCurrentAgDatabases
AS
WITH X AS
(
    SELECT D.*,
           ROW_NUMBER() OVER
           (
               PARTITION BY InstanceId,GroupName,DatabaseName
               ORDER BY CapturedAt DESC,DatabaseReplicaSnapshotId DESC
           ) rn
    FROM ha.DatabaseReplicaSnapshot D
)
SELECT I.ServerInstance,E.EnvironmentCode,X.*
FROM X
JOIN dbo.Instance I ON I.InstanceId=X.InstanceId
LEFT JOIN dbo.Environment E ON E.EnvironmentId=I.EnvironmentId
WHERE rn=1;
GO

CREATE OR ALTER VIEW report.vCurrentServerConfiguration
AS
WITH X AS
(
    SELECT C.*,
           ROW_NUMBER() OVER
           (
               PARTITION BY InstanceId,ConfigurationName
               ORDER BY CapturedAt DESC,ServerConfigurationSnapshotId DESC
           ) rn
    FROM config.ServerConfigurationSnapshot C
)
SELECT I.ServerInstance,E.EnvironmentCode,X.*
FROM X
JOIN dbo.Instance I ON I.InstanceId=X.InstanceId
LEFT JOIN dbo.Environment E ON E.EnvironmentId=I.EnvironmentId
WHERE rn=1;
GO

CREATE OR ALTER VIEW report.vCurrentServerPrincipals
AS
WITH X AS
(
    SELECT S.*,
           ROW_NUMBER() OVER
           (
               PARTITION BY InstanceId,PrincipalId
               ORDER BY CapturedAt DESC,ServerPrincipalSnapshotId DESC
           ) rn
    FROM security.ServerPrincipalSnapshot S
)
SELECT I.ServerInstance,E.EnvironmentCode,X.*
FROM X
JOIN dbo.Instance I ON I.InstanceId=X.InstanceId
LEFT JOIN dbo.Environment E ON E.EnvironmentId=I.EnvironmentId
WHERE rn=1;
GO

CREATE OR ALTER PROCEDURE report.usp_BackupCompliance
AS
BEGIN
    SET NOCOUNT ON;

    WITH L AS
    (
        SELECT InstanceId,DatabaseName,
               MAX(CASE WHEN BackupType='D' AND IsCopyOnly=0 THEN BackupFinishDate END) LastFull,
               MAX(CASE WHEN BackupType='I' THEN BackupFinishDate END) LastDiff,
               MAX(CASE WHEN BackupType='L' THEN BackupFinishDate END) LastLog
        FROM backup.BackupHistory
        GROUP BY InstanceId,DatabaseName
    )
    SELECT
        D.ServerInstance,D.EnvironmentCode,D.DatabaseName,D.RecoveryModelDesc,
        L.LastFull,L.LastDiff,L.LastLog,
        CASE
          WHEN L.LastFull IS NULL THEN 'NO_FULL'
          WHEN D.RecoveryModelDesc='FULL' AND L.LastLog IS NULL THEN 'NO_LOG'
          WHEN D.RecoveryModelDesc='FULL' AND DATEDIFF(minute,L.LastLog,SYSDATETIME())>60 THEN 'OLD_LOG'
          WHEN DATEDIFF(hour,L.LastFull,SYSDATETIME())>36 THEN 'OLD_FULL'
          ELSE 'OK'
        END BackupStatus
    FROM report.vCurrentDatabases D
    LEFT JOIN L
      ON L.InstanceId=D.InstanceId
     AND L.DatabaseName=D.DatabaseName
    WHERE D.DatabaseName<>'tempdb'
    ORDER BY BackupStatus,D.ServerInstance,D.DatabaseName;
END;
GO

CREATE OR ALTER PROCEDURE report.usp_CapacityRisk
AS
BEGIN
    SELECT
        ServerInstance,EnvironmentCode,VolumeMountPoint,TotalGB,AvailableGB,FreePercent,
        CASE WHEN FreePercent<10 THEN 'CRITICAL'
             WHEN FreePercent<20 THEN 'WARNING'
             ELSE 'OK' END CapacityStatus
    FROM report.vCurrentVolumes
    ORDER BY FreePercent,ServerInstance,VolumeMountPoint;
END;
GO

CREATE OR ALTER PROCEDURE report.usp_HaHealth
AS
BEGIN
    SELECT
        ServerInstance,EnvironmentCode,GroupName,DatabaseName,IsPrimaryReplica,
        SynchronizationStateDesc,SynchronizationHealthDesc,DatabaseStateDesc,
        IsSuspended,LogSendQueueKB,RedoQueueKB,LastCommitTime,
        CASE WHEN SynchronizationHealthDesc='NOT_HEALTHY' OR IsSuspended=1 THEN 'CRITICAL'
             WHEN SynchronizationStateDesc NOT IN('SYNCHRONIZED','SYNCHRONIZING') THEN 'WARNING'
             ELSE 'OK' END HaStatus
    FROM report.vCurrentAgDatabases
    ORDER BY HaStatus,ServerInstance,GroupName,DatabaseName;
END;
GO
