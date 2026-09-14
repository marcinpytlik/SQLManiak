# Stage 2 — Debezium + Kafka

## Cel

Podłączyć Debezium do działającego SQL Server CDC i publikować zmiany do Kafka.

## Kolejność

```text
Debezium/00_CreateDebeziumLogin.sql
Debezium/01_Start.ps1
Debezium/02_RegisterConnector.ps1
Debezium/03_Status.ps1
Debezium/04_ListTopics.ps1
```

## Kryterium PASS

- `sqllab-kafka` działa,
- `sqllab-debezium-connect` działa,
- connector `sqllab-sqlserver-cdc` ma stan `RUNNING`,
- task 0 ma stan `RUNNING`,
- topiki dla tabel istnieją.

## Ważne

Debezium nie zastępuje capture joba SQL Server CDC. Jeżeli `cdc.CDC_Lab_capture` stoi, connector może być `RUNNING`, ale nie otrzyma nowych zmian.

## Diagnostyka

```powershell
.\03_Status.ps1
docker logs sqllab-debezium-connect --tail 100
```

Po stronie SQL:

```sql
USE CDC_Lab;
GO
EXEC sys.sp_cdc_help_jobs;
SELECT TOP (20) * FROM sys.dm_cdc_errors ORDER BY entry_time DESC;
GO
```
