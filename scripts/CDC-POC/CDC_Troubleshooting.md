# SQL Server CDC + Debezium — Troubleshooting Runbook

Ten dokument opisuje szybką diagnostykę sytuacji, w której SQL Server CDC albo Debezium przestają dostarczać zmiany.

---

## 1. Najważniejszy łańcuch diagnostyczny

Jeżeli w Debezium nie pojawiają się nowe eventy, sprawdzaj warstwy w tej kolejności:

```text
Tabela źródłowa
    ↓
Transaction Log
    ↓
CDC capture job
    ↓
cdc.*_CT
    ↓
Debezium connector
    ↓
Kafka topic
    ↓
Consumer
```

Nie zaczynaj od restartu Debezium. Najpierw sprawdź, czy SQL Server rzeczywiście przeniósł zmianę do change table.

---

## 2. Objaw: INSERT/UPDATE/DELETE jest w tabeli źródłowej, ale nie ma go w `cdc.*_CT`

To dokładnie przypadek, który wystąpił podczas POC.

Przykład testu:

```sql
USE CDC_Lab;
GO

INSERT dbo.Customer
(
    FirstName,
    LastName,
    Email
)
VALUES
(
    'CDC',
    'Troubleshooting',
    'cdc@sqllab.local'
);
GO
```

Sprawdź tabelę źródłową:

```sql
SELECT *
FROM dbo.Customer
WHERE LastName = 'Troubleshooting';
GO
```

Jeżeli rekord istnieje, ale po kilku sekundach nie pojawia się tutaj:

```sql
SELECT TOP (50) *
FROM cdc.dbo_Customer_CT
ORDER BY __$start_lsn DESC;
GO
```

najpierw sprawdź capture job.

---

## 3. Sprawdzenie jobów CDC

```sql
USE CDC_Lab;
GO

EXEC sys.sp_cdc_help_jobs;
GO
```

Oczekujemy co najmniej:

```text
capture
cleanup
```

Dla bazy `CDC_Lab` SQL Agent tworzy zwykle joby:

```text
cdc.CDC_Lab_capture
cdc.CDC_Lab_cleanup
```

Szczególnie ważny jest:

```text
cdc.CDC_Lab_capture
```

Jeżeli nie działa, nowe rekordy pozostają tylko w transaction logu i nie trafiają do change tables.

---

## 4. Status capture joba

```sql
SELECT
    j.name,
    j.enabled,
    ja.start_execution_date,
    ja.stop_execution_date,
    ja.last_executed_step_id,
    ja.last_executed_step_date
FROM msdb.dbo.sysjobs AS j
LEFT JOIN msdb.dbo.sysjobactivity AS ja
    ON ja.job_id = j.job_id
   AND ja.session_id =
   (
       SELECT MAX(session_id)
       FROM msdb.dbo.syssessions
   )
WHERE j.name LIKE N'cdc.CDC_Lab%';
GO
```

Jeżeli capture job nie działa, uruchom go:

```sql
EXEC msdb.dbo.sp_start_job
    @job_name = N'cdc.CDC_Lab_capture';
GO
```

Jeżeli dostaniesz komunikat, że job już działa, przejdź do diagnostyki sesji log scan i błędów CDC.

---

## 5. Sesje CDC log scan

```sql
USE CDC_Lab;
GO

SELECT TOP (50)
    session_id,
    start_time,
    end_time,
    duration,
    scan_phase,
    error_count,
    tran_count,
    command_count
FROM sys.dm_cdc_log_scan_sessions
ORDER BY session_id DESC;
GO
```

Interpretacja:

- pojawiają się nowe sesje — capture process pracuje,
- `error_count > 0` — przejdź do `sys.dm_cdc_errors`,
- brak nowych sesji — capture job prawdopodobnie nie pracuje poprawnie.

---

## 6. Błędy CDC

```sql
USE CDC_Lab;
GO

SELECT TOP (50)
    entry_time,
    start_lsn,
    begin_lsn,
    sequence_value,
    error_number,
    error_severity,
    error_state,
    error_message
FROM sys.dm_cdc_errors
ORDER BY entry_time DESC;
GO
```

Po zmianach schematu lub problemach z typami danych to jedno z pierwszych miejsc do sprawdzenia.

---

## 7. Czy CDC jest nadal aktywne?

### Baza

```sql
SELECT
    name,
    is_cdc_enabled,
    log_reuse_wait_desc
FROM sys.databases
WHERE name = N'CDC_Lab';
GO
```

### Tabele

```sql
USE CDC_Lab;
GO

SELECT
    name,
    is_tracked_by_cdc
FROM sys.tables
WHERE name IN (N'Customer', N'CustomerOrder');
GO
```

Oczekujemy `is_cdc_enabled = 1` oraz `is_tracked_by_cdc = 1`.

---

## 8. Czy change tables są na właściwym filegroup?

POC używa dedykowanego filegroup:

```text
CDC_CT
```

Sprawdzenie:

```sql
USE CDC_Lab;
GO

SELECT
    OBJECT_SCHEMA_NAME(ct.source_object_id) AS source_schema,
    OBJECT_NAME(ct.source_object_id) AS source_table,
    ct.capture_instance,
    ct.filegroup_name
FROM cdc.change_tables AS ct
ORDER BY source_schema, source_table;
GO
```

Oczekiwane:

```text
filegroup_name = CDC_CT
```

Samo utworzenie filegroup w bazie nie przenosi tam CDC. Przy `sys.sp_cdc_enable_table` trzeba jawnie podać:

```sql
@filegroup_name = N'CDC_CT'
```

---

## 9. Objaw: dane są w `cdc.*_CT`, ale Debezium nic nie publikuje

Jeżeli change table ma nowe rekordy, problem jest już za warstwą CDC.

### Status connectora

```powershell
.\03_Status.ps1
```

Oczekujemy:

```text
connector = RUNNING
task      = RUNNING
```

### Logi Debezium

```powershell
docker logs sqllab-debezium-connect --tail 200
```

Szukaj m.in. błędów połączenia do SQL Servera, błędów LSN, problemów z uprawnieniami i błędów schema history.

---

## 10. Objaw: connector jest RUNNING, ale brak nowych eventów

Sprawdź po kolei:

1. czy rekord jest w tabeli źródłowej,
2. czy rekord trafił do `cdc.*_CT`,
3. czy `cdc.<db>_capture` działa,
4. czy `sys.dm_cdc_errors` nie pokazuje błędów,
5. czy connector ma status `RUNNING`,
6. czy topic istnieje,
7. czy consumer czyta właściwy topic i właściwy offset.

To ważne: status `RUNNING` w Debezium nie gwarantuje, że SQL Server CDC aktualnie dostarcza nowe zmiany. Jeżeli capture job stoi, Debezium może nadal pozostawać w stanie `RUNNING`, ale nie ma nowych danych do przeczytania.

---

## 11. Sprawdzenie topiców Kafka

```powershell
.\04_ListTopics.ps1
```

Dla tego POC oczekujemy m.in.:

```text
sqllab.CDC_Lab.dbo.Customer
sqllab.CDC_Lab.dbo.CustomerOrder
schemahistory.sqllab.CDC_Lab
```

---

## 12. Consumer od początku topicu

Domyślny consumer może czekać tylko na nowe rekordy.

Aby zobaczyć również istniejące eventy:

```powershell
.\05_Consume.ps1 -FromBeginning
```

To jest dobry test, czy topic rzeczywiście zawiera dane.

---

## 13. Test end-to-end

Najprostszy test:

```sql
USE CDC_Lab;
GO

INSERT dbo.Customer
(
    FirstName,
    LastName,
    Email
)
VALUES
(
    'Debezium',
    'EndToEnd',
    'e2e@sqllab.local'
);
GO
```

Następnie:

```sql
WAITFOR DELAY '00:00:05';
GO

SELECT TOP (20) *
FROM cdc.dbo_Customer_CT
ORDER BY __$start_lsn DESC;
GO
```

Jeżeli rekord jest w CT, ale nie ma go w Kafka — diagnozuj Debezium/Kafka.

Jeżeli nie ma go w CT — diagnozuj capture job / log scan.

---

## 14. Szybka tabela diagnostyczna

| Objaw | Najbardziej prawdopodobna warstwa | Pierwszy test |
|---|---|---|
| Rekord jest w tabeli, nie ma go w CT | CDC capture | `sp_cdc_help_jobs` |
| Capture job działa, brak CT | CDC log scan | `sys.dm_cdc_log_scan_sessions` |
| CT ma dane, brak eventu Kafka | Debezium | `03_Status.ps1` + logi kontenera |
| Connector RUNNING, brak zmian | CDC lub offset | sprawdź CT i consumer `-FromBeginning` |
| Brak topicu | Debezium/Kafka | `04_ListTopics.ps1` |
| Topic istnieje, consumer nic nie pokazuje | offset consumera | `05_Consume.ps1 -FromBeginning` |
| Po zmianie schematu capture stoi | CDC metadata / typ danych | `sys.dm_cdc_errors` + DDL history |

---

## 15. Wniosek z POC

Praktyczna zasada diagnostyczna:

> Jeśli Debezium nie publikuje zmian, najpierw sprawdź `cdc.*_CT`. Jeśli change table nie ma nowych danych, nie diagnozuj jeszcze Debezium — problem znajduje się wcześniej, najczęściej w capture jobie albo log scan.

Ten przypadek został potwierdzony w SQLLab: `cdc.CDC_Lab_capture` nie działał. Po uruchomieniu joba zmiany zaczęły trafiać do change tables, a Debezium/Kafka natychmiast wznowiły przepływ eventów.
