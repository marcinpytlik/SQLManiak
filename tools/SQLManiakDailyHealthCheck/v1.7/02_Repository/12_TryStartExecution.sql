/* DHC v1.7: atomic, due-aware execution claim.
   Run on SQLManiakHealthHistory AFTER 08_ExecutionLog.sql.
   Adds no scheduler or SQL Agent job. Existing history is preserved.
*/
USE SQLManiakHealthHistory;
GO
IF OBJECT_ID(N'dhc.MonitoredServer',N'U') IS NULL
 OR OBJECT_ID(N'dhc.ExecutionLog',N'U') IS NULL
    THROW 51040, 'Install inventory and ExecutionLog first (04 and 08).', 1;
GO
CREATE OR ALTER PROCEDURE dhc.TryStartExecution
    @ServerId int,
    @ExecutionId uniqueidentifier,
    @Force bit=0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Decision varchar(16)='NOT_FOUND',
            @LastStartedUTC datetime2(3)=NULL,
            @LastStatus varchar(16)=NULL,
            @ServerInstance nvarchar(256)=NULL,
            @IntervalMinutes int=NULL,
            @IsEnabled bit=NULL,
            @Resource nvarchar(255)=CONCAT(N'DHC_MONITOR_',CONVERT(nvarchar(12),@ServerId)),
            @LockResult int,
            @Now datetime2(3)=SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @LockResult=sys.sp_getapplock
             @Resource=@Resource,
             @LockMode='Exclusive',
             @LockOwner='Transaction',
             @LockTimeout=10000,
             @DbPrincipal='public';
        IF @LockResult < 0
            THROW 51041, 'Could not acquire the per-server scheduling lock.',1;

        SELECT @ServerInstance=ServerInstance,
               @IntervalMinutes=IntervalMinutes,
               @IsEnabled=IsEnabled
        FROM dhc.MonitoredServer WITH (UPDLOCK, HOLDLOCK)
        WHERE ServerId=@ServerId;

        IF @ServerInstance IS NULL
            SET @Decision='NOT_FOUND';
        ELSE IF @IsEnabled=0
            SET @Decision='DISABLED';
        ELSE
        BEGIN
            SELECT TOP (1)
                @LastStartedUTC=StartedUTC,
                @LastStatus=Status
            FROM dhc.ExecutionLog
            WHERE ServerInstance=@ServerInstance
            ORDER BY StartedUTC DESC, ExecutionId DESC;

            IF @LastStatus='RUNNING'
                SET @Decision='RUNNING';
            ELSE IF @Force=0
                 AND @LastStartedUTC IS NOT NULL
                 AND DATEADD(MINUTE,@IntervalMinutes,@LastStartedUTC)>@Now
                SET @Decision='NOT_DUE';
            ELSE
            BEGIN
                INSERT dhc.ExecutionLog
                    (ExecutionId,ServerId,ServerInstance,StartedUTC,Status)
                VALUES
                    (@ExecutionId,@ServerId,@ServerInstance,@Now,'RUNNING');
                SET @Decision='CLAIMED';
            END
        END;

        COMMIT TRANSACTION;
        SELECT @Decision AS Decision,
               @ServerInstance AS ServerInstance,
               @LastStatus AS PreviousStatus,
               @LastStartedUTC AS PreviousAttemptUTC,
               @Now AS EvaluatedUTC;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
-- This query does NOT create an execution attempt.
SELECT s.ServerId,s.ServerInstance,s.IntervalMinutes,s.IsEnabled,
       v.MonitoringStatus,v.LastAttemptUTC,v.IsOverdue
FROM dhc.MonitoredServer AS s
LEFT JOIN dhc.vMonitoringStatus AS v ON v.ServerId=s.ServerId
ORDER BY s.ServerId;
GO
