/* Job: Replication – Email New Errors (Hourly)
   Wymaga:
   - Database Mail (sprawdź profil domyślny)
   - Operator o nazwie @MailOperator (zmień jeśli potrzeba)
*/
DECLARE @MailOperator sysname = N'$(MailOperator)'; -- podmień w VS Code lub ręcznie
DECLARE @JobName sysname = N'Replication – Email New Errors (Hourly)';

USE msdb;
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
BEGIN
  EXEC sp_delete_job @job_name = @JobName;
END

EXEC sp_add_job 
    @job_name = @JobName, 
    @enabled = 1, 
    @description = N'Wysyła e-mail z nowymi błędami z MSrepl_errors co godzinę.';

EXEC sp_add_jobstep 
    @job_name = @JobName,
    @step_name = N'Send Error Digest',
    @subsystem = N'TSQL',
    @database_name = N'distribution',
    @command = N'
;WITH cte AS (
  SELECT TOP (100)
    e.id, e.time, e.error_code, e.xact_seqno, e.command_id, e.error_text
  FROM dbo.MSrepl_errors e
  WHERE e.time > DATEADD(HOUR, -1, GETDATE())
  ORDER BY e.time DESC
)
SELECT * FROM cte;
',
    @retry_attempts = 2,
    @retry_interval = 2;

EXEC sp_add_schedule 
    @schedule_name = N'Hourly',
    @enabled = 1,
    @freq_type = 4,            -- daily
    @freq_interval = 1,
    @freq_subday_type = 8,     -- hours
    @freq_subday_interval = 1, -- every 1 hour
    @active_start_time = 0;

EXEC sp_attach_schedule @job_name = @JobName, @schedule_name = N'Hourly';

EXEC sp_add_jobserver @job_name = @JobName;

-- Operator powiadomień
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = @MailOperator)
BEGIN
  PRINT ''[WARN] Operator '' + @MailOperator + '' nie istnieje. Utwórz operatora lub zmień nazwę w skrypcie.'';
END
ELSE
BEGIN
  EXEC msdb.dbo.sp_update_job @job_name = @JobName, @notify_level_email = 2, @notify_email_operator_name = @MailOperator;
END
