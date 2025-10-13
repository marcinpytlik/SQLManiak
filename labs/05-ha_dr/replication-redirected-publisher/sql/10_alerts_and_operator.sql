/*
  Operator + Alerty SQL Agent dla replikacji
  - Tworzy Operatora (email)
  - Alert 14151 (Replication agent failed)
  - Alert 14157 (Subskrypcja nieaktywna / wymaga reinit)
  - Opcjonalnie podpina powiadomienia do jobów agentów replikacji

  Uruchom na serwerze, gdzie działają joby agentów (A lub C – zależnie od etapu).
*/

-- =============== PARAMETRY ===============
DECLARE @OperatorName sysname = N'ReplOps';
DECLARE @OperatorEmail nvarchar(256) = N'dba-team@example.com';  -- ZMIEŃ
DECLARE @AttachToJobsLike nvarchar(128) = N'%Agent%';            -- pattern nazw jobów
DECLARE @NotifyLevel int = 2;  -- 1=Success,2=Failure,3=Completion (dla job notifications)
-- =========================================

-- 1) Operator
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = @OperatorName)
BEGIN
    EXEC msdb.dbo.sp_add_operator
        @name = @OperatorName,
        @enabled = 1,
        @email_address = @OperatorEmail;
END
ELSE
BEGIN
    EXEC msdb.dbo.sp_update_operator
        @name = @OperatorName,
        @email_address = @OperatorEmail,
        @enabled = 1;
END

-- 2) Alert 14151 – agent failed
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysalerts WHERE name = N'Replication Agent Failed (14151)')
BEGIN
    EXEC msdb.dbo.sp_add_alert
        @name = N'Replication Agent Failed (14151)',
        @message_id = 14151,
        @severity = 0,
        @delay_between_responses = 300,  -- 5 min
        @include_event_description_in = 1,
        @job_id = NULL;
    EXEC msdb.dbo.sp_add_notification
        @alert_name = N'Replication Agent Failed (14151)',
        @operator_name = @OperatorName,
        @notification_method = 1; -- email
END

-- 3) Alert 14157 – subscription inactive / reinit needed
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysalerts WHERE name = N'Replication Subscription Inactive (14157)')
BEGIN
    EXEC msdb.dbo.sp_add_alert
        @name = N'Replication Subscription Inactive (14157)',
        @message_id = 14157,
        @severity = 0,
        @delay_between_responses = 300,
        @include_event_description_in = 1,
        @job_id = NULL;
    EXEC msdb.dbo.sp_add_notification
        @alert_name = N'Replication Subscription Inactive (14157)',
        @operator_name = @OperatorName,
        @notification_method = 1;
END

-- 4) (Opcjonalnie) Dołącz operatora do wszystkich jobów agentów
DECLARE @job_id uniqueidentifier, @job_name sysname;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT job_id, name
    FROM msdb.dbo.sysjobs
    WHERE name LIKE @AttachToJobsLike;  -- np. '%Agent%': Snapshot/Log Reader/Distribution Agent

OPEN cur;
FETCH NEXT FROM cur INTO @job_id, @job_name;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC msdb.dbo.sp_update_job
        @job_id = @job_id,
        @notify_level_email = @NotifyLevel,
        @notify_email_operator_name = @OperatorName;
    FETCH NEXT FROM cur INTO @job_id, @job_name;
END
CLOSE cur; DEALLOCATE cur;

PRINT 'Skonfigurowano operatora i alerty. Dołączono powiadomienia do jobów zgodnych z patternem: ' + @AttachToJobsLike;
