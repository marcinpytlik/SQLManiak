/* sql/99_cleanup.sql
   Sprzątanie obiektów (ostrożnie!)
*/

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'AuditDailyAgg Loader')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'AuditDailyAgg Loader';
END
GO

IF OBJECT_ID('dbo.Refresh_AuditDailyAgg','P') IS NOT NULL
    DROP PROCEDURE dbo.Refresh_AuditDailyAgg;
GO

IF OBJECT_ID('dbo.AuditDailyAgg','U') IS NOT NULL
    DROP TABLE dbo.AuditDailyAgg;
GO

IF OBJECT_ID('dbo.ufn_AuditEvents','IF') IS NOT NULL
    DROP FUNCTION dbo.ufn_AuditEvents;
GO
