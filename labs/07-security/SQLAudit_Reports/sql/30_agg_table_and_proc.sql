/* sql/30_agg_table_and_proc.sql
   Tabela dziennych agregatów + procedura odświeżająca z TVF
*/

IF OBJECT_ID('dbo.AuditDailyAgg','U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditDailyAgg(
        [date]        date        NOT NULL,
        principal     sysname     NOT NULL,
        operation     varchar(16) NOT NULL,
        obj3          nvarchar(776) NULL,
        calls         bigint      NOT NULL,
        CONSTRAINT PK_AuditDailyAgg PRIMARY KEY([date], principal, operation, obj3)
    );
END
GO

IF OBJECT_ID('dbo.Refresh_AuditDailyAgg','P') IS NOT NULL
    DROP PROCEDURE dbo.Refresh_AuditDailyAgg;
GO

CREATE PROCEDURE dbo.Refresh_AuditDailyAgg
    @AuditName sysname,
    @FromDate  date = NULL,
    @ToDate    date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @ToDate IS NULL  SET @ToDate  = CAST(SYSDATETIME() AS date);
    IF @FromDate IS NULL SET @FromDate= DATEADD(day, -1, @ToDate);

    ;WITH B AS (
        SELECT 
            CAST(event_time_local AS date) AS [date],
            principal,
            operation,
            obj3,
            COUNT(*) AS calls
        FROM dbo.ufn_AuditEvents(@AuditName, @FromDate, DATEADD(day,1,@ToDate)) -- półotwarty przedział
        GROUP BY CAST(event_time_local AS date), principal, operation, obj3
    )
    MERGE dbo.AuditDailyAgg AS T
    USING B AS S
      ON T.[date]=S.[date] AND T.principal=S.principal AND T.operation=S.operation AND ISNULL(T.obj3,'')=ISNULL(S.obj3,'')
    WHEN MATCHED THEN UPDATE SET
        calls = S.calls
    WHEN NOT MATCHED BY TARGET THEN
        INSERT([date], principal, operation, obj3, calls)
        VALUES(S.[date], S.principal, S.operation, S.obj3, S.calls);
END
GO
