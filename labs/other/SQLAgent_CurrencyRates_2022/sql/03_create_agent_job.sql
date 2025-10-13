-- sql/03_create_agent_job.sql
/*
Tworzy job SQL Server Agent, który wywołuje ps/FetchNbpRates.ps1 raz dziennie.
Parametryzacja: @InstanceName, @DbName
*/
DECLARE @InstanceName sysname = N'localhost'; -- <- USTAW
DECLARE @DbName      sysname = N'Finance';   -- <- USTAW
DECLARE @JobName     sysname = N'NBP Rates Import (Table A)';
DECLARE @JobDescription nvarchar(4000) = N'Pobiera kursy walut NBP (tabela A) i MERGE do dbo.ExchangeRates.';

-- ścieżka do PS w repo (dopasuj jeżeli kopiujesz gdzie indziej)
DECLARE @PsPath nvarchar(4000) = N'$(ESCAPE_SQUOTE(SQLDIR))\SQLAgent_CurrencyRates_2022\ps\FetchNbpRates.ps1';
-- Wskazówka: możesz też użyć pełnej ścieżki, np. C:\Repo\SQLAgent_CurrencyRates_2022\ps\FetchNbpRates.ps1

-- Bezpieczne usuwanie poprzedniego joba
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
    EXEC msdb.dbo.sp_delete_job @job_name = @JobName;

-- 1) Utwórz job
EXEC msdb.dbo.sp_add_job
    @job_name        = @JobName,
    @enabled         = 1,
    @description     = @JobDescription,
    @notify_level_eventlog = 2,
    @category_name   = N'[Uncategorized (Local)]';

-- 2) Dodaj krok PowerShell
DECLARE @Cmd nvarchar(max) =
N'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + @PsPath + N'" -SqlInstance "' + @InstanceName + N'" -Database "' + @DbName + N'"';

EXEC msdb.dbo.sp_add_jobstep
    @job_name      = @JobName,
    @step_name     = N'Fetch NBP Rates (A)',
    @subsystem     = N'PowerShell',
    @command       = @Cmd,
    @retry_attempts= 2,
    @retry_interval= 5,
    @on_fail_action= 2; -- Quit with failure

-- 3) Harmonogram: codziennie 12:15 Europe/Warsaw
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'EveryDay_12h15_Warsaw',
    @freq_type     = 4,       -- daily
    @freq_interval = 1,
    @active_start_time = 121500; -- 12:15:00

EXEC msdb.dbo.sp_attach_schedule
    @job_name      = @JobName,
    @schedule_name = N'EveryDay_12h15_Warsaw';

-- 4) Przypnij job do serwera
EXEC msdb.dbo.sp_add_jobserver
    @job_name = @JobName;

PRINT 'Job utworzony. Sprawdź historię w SQL Server Agent.';
