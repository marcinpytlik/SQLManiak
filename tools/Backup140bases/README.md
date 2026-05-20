# SQL Server — backupy sterowane tabelą konfiguracji w `msdb`

Ten pakiet tworzy mechanizm backupów, w którym lokalizacja backupu jest przypisana do bazy w tabeli:

```sql
msdb.dbo.DBA_BackupDatabaseConfig
```

Dla Twojego przykładu:

```text
baza1, baza2, baza3 -> X:\backup
baza5, baza6, baza7 -> Z:\backup
```

Przy 140 bazach joby nie zawierają listy baz. Joby wołają procedurę:

```sql
EXEC msdb.dbo.usp_BackupDatabases_ByConfig @BackupType = 'FULL';
EXEC msdb.dbo.usp_BackupDatabases_ByConfig @BackupType = 'DIFF';
EXEC msdb.dbo.usp_BackupDatabases_ByConfig @BackupType = 'LOG';
```

Procedura czyta konfigurację z tabeli i zapisuje backupy do odpowiedniego katalogu.

## Kolejność uruchomienia na `sql32\sqlins`

```powershell
sqlcmd -S "syriusz" -E -i .\01_create_backup_config_tables.sql
sqlcmd -S "syriusz" -E -i .\02_create_backup_procedure_by_config.sql
sqlcmd -S "syriusz" -E -i .\03_seed_example_config.sql
sqlcmd -S "syriusz" -E -i .\04_create_sql_agent_jobs_by_config.sql
sqlcmd -S "syriusz" -E -i .\05_test_and_verify.sql
```

## Najważniejsze operacje

Zmiana lokalizacji backupu jednej bazy:

```sql
UPDATE msdb.dbo.DBA_BackupDatabaseConfig
SET BackupBasePath = N'Z:\backup',
    Notes = N'Przeniesiona na Z'
WHERE DatabaseName = N'MojaBaza';
```

Wyłączenie backupu jednej bazy:

```sql
UPDATE msdb.dbo.DBA_BackupDatabaseConfig
SET IsEnabled = 0
WHERE DatabaseName = N'MojaBaza';
```

Plan bez wykonywania backupu:

```sql
EXEC msdb.dbo.usp_BackupDatabases_ByConfig
    @BackupType = 'FULL',
    @DryRun = 1;
```

Pliki powstaną w układzie:

```text
X:\backup\ERP_PROD\ERP_PROD_20260519_203000_FULL.bak
Z:\backup\CRM_PROD\CRM_PROD_20260519_203000_FULL.bak
```
