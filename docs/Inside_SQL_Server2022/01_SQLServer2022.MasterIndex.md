# 📌 SQL Server 2022 — Master Index (Where-to-look)

## Foldery / pliki
- Engine binarki: `C:\Program Files\Microsoft SQL Server\MSSQL16.<Instance>\MSSQL\Binn\`
- Bazy domyślne / user DB: `...\MSSQL\DATA\`
- Logi (ERRORLOG, Agent, XE): `...\MSSQL\Log\`
- ReplData: `...\MSSQL\ReplData\`
- Setup logs: `C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\Log\`
- ProgramData (ukryte): `C:\ProgramData\Microsoft\SQL Server\`

## Rejestr (HKLM)
- Instancje: `SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL`
- Parametry startowe: `...\MSSQL16.<Instance>\MSSQLServer\Parameters`  (`-d`, `-l`, `-e`)
- Sieć/porty: `...\MSSQL16.<Instance>\MSSQLServer\SuperSocketNetLib`
- Usługi: `SYSTEM\CurrentControlSet\Services\{MSSQLSERVER | MSSQL$Name | SQLAgent$Name}`

## Logi (główne)
- ERRORLOG: `...\MSSQL\Log\ERRORLOG`
- SQL Agent: `...\MSSQL\Log\SQLAGENT.OUT`
- Backup/Restore: msdb (`backupset`, `restorehistory`)
- Extended Events: `...\MSSQL\Log\system_health*.xel`
- Setup Bootstrap: `...\Setup Bootstrap\Log\{date}\Summary.txt`, `Detail.txt`
- Audit: pliki `.sqlaudit` lub Windows Application Log

## Usługi
- Engine: `MSSQLSERVER` / `MSSQL$Name`
- Agent: `SQLSERVERAGENT` / `SQLAgent$Name`
- Browser: `SQLBrowser`
- Full-Text: `MSSQLFDLauncher($Name)`
- Launchpad/ML: `MSSQLLaunchpad($Name)`
- SSRS/SSAS/SSIS/PolyBase: wg instalacji

## Szybkie komendy
```sql
-- Domyślne ścieżki
SELECT SERVERPROPERTY('InstanceDefaultDataPath'), SERVERPROPERTY('InstanceDefaultLogPath');

-- ERRORLOG (ostatni)
EXEC sys.xp_readerrorlog 0, 1;

-- system_health
SELECT * FROM sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL);
