# Troubleshooting: I/O

## Symptoms

- wzrost latencji plików danych lub logu,
- PAGEIOLATCH_*,
- WRITELOG,
- dłuższe backupy lub restore,
- niestabilny czas odpowiedzi zapytań zależnych od storage.

## First checks

1. Latencja per plik.
2. Latencja per wolumen.
3. Typ workloadu: data vs log.
4. Wait statistics.
5. Rozkład odczytów/zapisów.
6. Korelacja z backupem, CHECKDB, autogrowth lub innymi zadaniami.

## Existing sources of truth

- [DBA Daily Pack – 06_IO_Latency_And_Volumes.sql](../../tools/DBADaillyPack/sql/06_IO_Latency_And_Volumes.sql)
- [DBA Daily Pack – waits baseline/delta](../../tools/DBADaillyPack/sql/05_Waits_Baseline_And_Delta.sql)
- [Zabbix custom query – sqlmaniak_io_latency.sql](../../scripts/zabbix-mssql-monitoring/custom-queries/sqlmaniak_io_latency.sql)

## Evidence to collect

- baza,
- logical file,
- physical path,
- volume,
- read latency,
- write latency,
- bytes read/written,
- wait profile,
- czas rozpoczęcia problemu,
- równoległe operacje administracyjne.

## Validation

Porównuj do **baseline danego serwera**, nie do jednej arbitralnej wartości dla wszystkich środowisk.
