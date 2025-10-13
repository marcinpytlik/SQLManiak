/*
  Operator + Alerty SQL Agent dla replikacji
  - Operator (email)
  - Alert 14151 (Replication agent failed)
  - Alert 14157 (Subscription inactive / reinit needed)
  - Opcjonalne podpięcie powiadomień do jobów replikacyjnych
*/
DECLARE @OperatorName sysname = N'ReplOps';
DECLARE @OperatorEmail nvarchar(256) = N'dba-team@example.com';  -- ZMIEŃ
DECLARE @AttachToJobsLike nvarchar(128) = N'%Agent%';
DECLARE @NotifyLevel int = 2;  -- 2=Failure

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = @OperatorName)
BEGIN
  EXEC msdb.dbo.sp_add_operator @name=@OperatorName, @enabled=1, @email_address=@OperatorEmail;
END
ELSE
BEGIN
  EXEC msdb.dbo.sp_update_operator @name=@OperatorName, @enabled=1, @email_address=@OperatorEmail;
END

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysalerts WHERE name = N'Replication Agent Failed (14151)')
BEGIN
  EXEC msdb.dbo.sp_add_alert @name=N'Replication Agent Failed (14151)', @message_id=14151, @delay_between_responses=300, @include_event_description_in=1;
  EXEC msdb.dbo.sp_add_notification @alert_name=N'Replication Agent Failed (14151)', @operator_name=@OperatorName, @notification_method=1;
END

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysalerts WHERE name = N'Replication Subscription Inactive (14157)')
BEGIN
  EXEC msdb.dbo.sp_add_alert @name=N'Replication Subscription Inactive (14157)', @message_id=14157, @delay_between_responses=300, @include_event_description_in=1;
  EXEC msdb.dbo.sp_add_notification @alert_name=N'Replication Subscription Inactive (14157)', @operator_name=@OperatorName, @notification_method=1;
END

DECLARE @job_id uniqueidentifier;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
  SELECT job_id FROM msdb.dbo.sysjobs WHERE name LIKE @AttachToJobsLike;
OPEN cur;
FETCH NEXT FROM cur INTO @job_id;
WHILE @@FETCH_STATUS = 0
BEGIN
  EXEC msdb.dbo.sp_update_job @job_id=@job_id, @notify_level_email=@NotifyLevel, @notify_email_operator_name=@OperatorName;
  FETCH NEXT FROM cur INTO @job_id;
END
CLOSE cur; DEALLOCATE cur;
PRINT 'Operator/alerty skonfigurowane i podpięte do jobów pasujących do wzorca.';
