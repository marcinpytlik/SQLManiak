# Stage 1 — SQL Server CDC

## Cel

Zbudować i zweryfikować natywną warstwę SQL Server CDC bez Debezium i Kafka.

## Zakres

```text
00_CreateDatabase.sql
01_CreateTables.sql
02_EnableCDC.sql
03_GenerateData.sql
04_ReadChanges.sql
05_CDC_Monitoring.sql
06_CDC_Retention.sql
```

## Kryterium PASS

- `CDC_Lab` istnieje i ma filegroup `CDC_CT`,
- tabele źródłowe istnieją,
- CDC jest włączone na bazie i tabelach,
- `cdc.CDC_Lab_capture` działa,
- zmiany trafiają do `cdc.*_CT`,
- monitoring CDC nie pokazuje błędów krytycznych.

## Najważniejszy test diagnostyczny

```sql
USE CDC_Lab;
GO
EXEC sys.sp_cdc_help_jobs;
GO

SELECT TOP (20) *
FROM cdc.dbo_Customer_CT
ORDER BY __$start_lsn DESC;
GO
```

Jeżeli DML jest w tabeli źródłowej, ale nie ma go w CT, najpierw sprawdź capture job i `sys.dm_cdc_errors`.

## Wynik etapu

```text
SQL Server DML -> log -> CDC capture -> CT
```
