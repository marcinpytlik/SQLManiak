# TEST 03 — Restart SQL Server

Cel: potwierdzić, że po restarcie SQL Server warstwa CDC oraz Debezium wracają do poprawnej pracy i nie ma luki w zmianach.

## Przed restartem

W SSMS:

```sql
USE CDC_Lab;
GO

INSERT dbo.Customer (FirstName, LastName, Email)
VALUES ('SQL','BeforeRestart','sql.before@test.local');
GO

EXEC sys.sp_cdc_help_jobs;
GO
```

Sprawdź, że `cdc.CDC_Lab_capture` działa i rekord pojawił się w `cdc.dbo_Customer_CT`.

## Restart

Zrestartuj usługę/instancję SQL Server zgodnie ze sposobem używanym w Twoim labie.

Nie zakładamy w tym pliku konkretnej nazwy usługi (`MSSQLSERVER` vs named instance).

## Po restarcie

Uruchom:

```sql
USE CDC_Lab;
GO

SELECT name, is_cdc_enabled
FROM sys.databases
WHERE name = N'CDC_Lab';
GO

EXEC sys.sp_cdc_help_jobs;
GO

SELECT TOP (20)
    session_id,
    start_time,
    end_time,
    duration,
    error_count,
    tran_count,
    command_count
FROM sys.dm_cdc_log_scan_sessions
ORDER BY session_id DESC;
GO

SELECT TOP (20) *
FROM sys.dm_cdc_errors
ORDER BY entry_time DESC;
GO
```

Następnie wykonaj:

```sql
INSERT dbo.Customer (FirstName, LastName, Email)
VALUES ('SQL','AfterRestart','sql.after@test.local');
GO
```

Po stronie Docker:

```powershell
cd .\scripts\CDC-POC\Debezium
.\03_Status.ps1
```

## PASS

- `CDC_Lab.is_cdc_enabled = 1`
- `cdc.CDC_Lab_capture` działa
- brak nowych krytycznych błędów w `sys.dm_cdc_errors`
- connector i task wracają do `RUNNING`
- event `BeforeRestart` oraz `AfterRestart` są dostępne downstream
