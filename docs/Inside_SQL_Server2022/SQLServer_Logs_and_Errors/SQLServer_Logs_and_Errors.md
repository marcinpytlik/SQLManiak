# Błędy, błędy, błędy — ile mamy logów i co w nich jest (SQL Server)

Ten mini‑przewodnik do repo pokazuje **jakie logi** ma SQL Server, **co zapisują**, **ile ich jest**, oraz **jak je czytać i filtrować** z poziomu T‑SQL.

---

## 1) Rodzaje logów

### 1.1 SQL Server Error Log (pliki `ERRORLOG`, `ERRORLOG.1` …)
- **Zawartość:** start/stop instancji, wersja/edycja, ścieżki, inicjalizacja pamięci, *recovery* baz, **BACKUP/RESTORE**, **AUTO‑GROW/AUTO‑SHRINK**, **login failures** (jeśli włączone), **deadlock info** (skrót, pełniej przez XE), błędy I/O, **stack dumps**, komunikaty `DBCC CHECKDB` (skrót), AlwaysOn/FCI zmiany stanu.
- **Lokalizacja (domyślnie):** `...\MSSQL\Log\ERRORLOG` (ścieżka zależna od instancji i parametru startowego `-e`).
- **Rotacja:** bieżący `ERRORLOG` + archiwa `ERRORLOG.1 ... ERRORLOG.N`.

### 1.2 SQL Server Agent Error Log (pliki `SQLAGENT.OUT`, `SQLAGENT.1` …)
- **Zawartość:** start/stop Agenta, konfiguracja, **wyniki kroków jobów**, błędy proxy, połączenia do serwera, rejestracja historii.
- **Lokalizacja (domyślnie):** `...\MSSQL\Log\SQLAGENT.OUT` (lub katalog instancji Agenta).
- **Rotacja:** analogicznie do ERRORLOG.

### 1.3 Windows Event Logs (Application/System)
- **Zawartość:** zrzuty kluczowych błędów serwisu, start/stop, błędy usług powiązanych (VSS, dyski, sieć). Dobre do korelacji z awariami hosta.

### 1.4 Extended Events — **system_health**
- **Zawartość:** **deadlock graph (XML)**, **error_reported** (ważniejsze błędy), timeouts, memory broker, schedulery; domyślnie włączone, zapis do pliku `.xel` i ring buffer.
- **Czytanie:** przez `sys.fn_xe_file_target_read_file` lub SSMS.

> Dodatkowo: **historia jobów** w `msdb.dbo.sysjobhistory` (to nie log tekstowy, ale często ważniejsza niż agentowy OUT).

---

## 2) Ile jest logów i jak to sprawdzić/ustawić

### 2.1 Policzenie i lista plików
```sql
-- Lista plików Error Log (SQL Server)
EXEC sys.xp_enumerrorlogs;  -- kolumny: Archive #, Date, Log File Size (Bytes), Log File Name

-- Lista plików Error Log dla SQL Agent
EXEC msdb.dbo.sp_help_agent_error_log;
```

### 2.2 Czytanie zawartości i szybkie filtrowanie
```sql
-- Czytaj bieżący ERRORLOG (Archive 0). Parametry: @p1=log#, @p2=log_type (1=SQL, 2=Agent)
EXEC sys.sp_readerrorlog @p1 = 0, @p2 = 1;

-- Szukaj konkretnej frazy (np. failed login) w archiwum #1
EXEC sys.sp_readerrorlog @p1 = 1, @p2 = 1, @p3 = 'Login failed';

-- Filtrowanie po dacie (od/do)
EXEC sys.sp_readerrorlog 
  @p1 = 0, @p2 = 1, 
  @p3 = NULL, @p4 = NULL,
  @p5 = '2025-09-01', @p6 = '2025-09-30';
```

### 2.3 Ręczna rotacja (recykling) logów
```sql
-- SQL Server Error Log: utwórz nowe ERRORLOG, dotychczasowy stanie się .1
EXEC sys.sp_cycle_errorlog;

-- SQL Agent Error Log: analogicznie
EXEC msdb.dbo.sp_cycle_agent_errorlog;
```
> **Uwaga:** Maksymalna liczba plików archiwalnych jest konfigurowalna w właściwościach serwera (SSMS → SQL Server Logs → Configure) i dla Agenta (SSMS → SQL Server Agent → Error Logs → Configure). Warto ustawić większą (np. 99) i zaplanować cotygodniowy recycling przez SQL Agent Job.

---

## 3) Co dokładnie trafia do ERRORLOG — szybkie zapytania

### 3.1 Ostatnie błędy i ostrzeżenia
```sql
-- Ostatnie 200 istotnych wpisów (hasła: error, fail, severity, deadlock)
DECLARE @tmp TABLE (LogDate NVARCHAR(64), ProcessInfo NVARCHAR(64), [Text] NVARCHAR(MAX));
INSERT @tmp EXEC sys.sp_readerrorlog @p1=0, @p2=1;
SELECT TOP (200) LogDate, ProcessInfo, [Text]
FROM @tmp
WHERE [Text] LIKE '%error%' 
   OR [Text] LIKE '%fail%'
   OR [Text] LIKE '%severity%'
   OR [Text] LIKE '%deadlock%'
ORDER BY LogDate DESC;
```

### 3.2 Nieudane logowania (jeśli włączone audytowanie nieudanych/sukcesów)
```sql
-- Włączone w: Server Properties → Security → Login auditing
DECLARE @t TABLE (LogDate NVARCHAR(64), ProcessInfo NVARCHAR(64), [Text] NVARCHAR(MAX));
INSERT @t EXEC sys.sp_readerrorlog @p1=0, @p2=1, @p3='Login failed';
SELECT TOP 100 * FROM @t ORDER BY LogDate DESC;
```

### 3.3 Zdarzenia AUTO‑GROW/AUTO‑SHRINK
```sql
DECLARE @g TABLE (LogDate NVARCHAR(64), ProcessInfo NVARCHAR(64), [Text] NVARCHAR(MAX));
INSERT @g EXEC sys.sp_readerrorlog @p1=0, @p2=1, @p3='Autogrow';
SELECT TOP 100 * FROM @g ORDER BY LogDate DESC;
```

### 3.4 Backup/Restore timeline
```sql
DECLARE @b TABLE (LogDate NVARCHAR(64), ProcessInfo NVARCHAR(64), [Text] NVARCHAR(MAX));
INSERT @b EXEC sys.sp_readerrorlog @p1=0, @p2=1, @p3='BACKUP';
INSERT @b EXEC sys.sp_readerrorlog @p1=0, @p2=1, @p3='RESTORE';
SELECT * FROM @b ORDER BY LogDate DESC;
```

---

## 4) Extended Events: deadlocki i poważne błędy

### 4.1 Deadlock graph z `system_health`
```sql
-- Zmień ścieżkę, jeśli logi XE są w innym katalogu
;WITH xe AS (
  SELECT CONVERT(XML, event_data) AS x
  FROM sys.fn_xe_file_target_read_file(
       'system_health*.xel', 'system_health*.xem', NULL, NULL)
  WHERE event_data IS NOT NULL
)
SELECT
  x.value('(event/@timestamp)[1]','datetime2') AS utc_time,
  x.query('.') AS full_event_xml
FROM xe
WHERE x.value('(event/@name)[1]','sysname') = 'xml_deadlock_report'
ORDER BY utc_time DESC;
```

### 4.2 Najnowsze poważne błędy (error_reported, severity ≥ 16)
```sql
;WITH xe AS (
  SELECT CONVERT(XML, event_data) AS x
  FROM sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL)
)
SELECT TOP 200
  x.value('(event/@timestamp)[1]','datetime2') AS utc_time,
  x.value('(event/data[@name="error_number"]/value)[1]','int') AS error_number,
  x.value('(event/data[@name="severity"]/value)[1]','int') AS severity,
  x.value('(event/data[@name="message"]/value)[1]','nvarchar(4000)') AS message
FROM xe
WHERE x.value('(event/@name)[1]','sysname') = 'error_reported'
  AND x.value('(event/data[@name="severity"]/value)[1]','int') >= 16
ORDER BY utc_time DESC;
```

---

## 5) Dobre praktyki
- **Powiększ liczbę archiwów** (np. do 99) i **planuj recycling** (np. co tydzień i przy rozruchu).
- **Nie trzymaj monstrualnego jednego ERRORLOG** – trudny do przeszukania i ryzyko braku miejsca.
- **Krytyczne rzeczy łap w XE** (deadlocki, timeouts, error_reported); log tekstowy traktuj jako dziennik „systemowy”.
- **Korelacja czasu**: miej świadomość UTC vs lokalny, host vs VM; zapisuj strefę w runbooku incydentów.
- **Backup logów** przy incydentach (skopiuj `ERRORLOG*`, `SQLAGENT*`, `system_health*.xel`).

---

## 6) Szybki check‑pack (one‑liners do diagnostyki)

```sql
-- 6.1 Ile mamy archiwów ERRORLOG (SQL)
EXEC sys.xp_enumerrorlogs;

-- 6.2 Najświeższe błędy Severity 17+ z ERRORLOG
DECLARE @e TABLE (LogDate NVARCHAR(64), ProcessInfo NVARCHAR(64), [Text] NVARCHAR(MAX));
INSERT @e EXEC sys.sp_readerrorlog @p1=0, @p2=1;
SELECT TOP 100 *
FROM @e
WHERE [Text] LIKE '%Severity: 17%'
   OR [Text] LIKE '%Severity: 18%'
   OR [Text] LIKE '%Severity: 19%'
   OR [Text] LIKE '%Severity: 20%'
   OR [Text] LIKE '%Severity: 21%'
   OR [Text] LIKE '%Severity: 22%'
   OR [Text] LIKE '%Severity: 23%'
   OR [Text] LIKE '%Severity: 24%'
ORDER BY LogDate DESC;

-- 6.3 Ostatnie 24h z frazami kluczowymi
DECLARE @k TABLE (LogDate NVARCHAR(64), ProcessInfo NVARCHAR(64), [Text] NVARCHAR(MAX));
INSERT @k EXEC sys.sp_readerrorlog @p1=0, @p2=1, @p5 = CONVERT(date, DATEADD(day, -1, SYSDATETIME()));
SELECT * FROM @k
WHERE [Text] LIKE '%Timeout%'
   OR [Text] LIKE '%I/O%'
   OR [Text] LIKE '%deadlock%'
   OR [Text] LIKE '%memory%'
ORDER BY LogDate DESC;
```

---

## 7) FAQ (skrótowo)
- **„Gdzie zmienić liczbę plików ERRORLOG?”**  
  W SSMS → *Management → SQL Server Logs → Configure* (ustaw „Maximum number of error log files”). Analogicznie dla Agenta.
- **„Czy mogę zmienić ścieżkę logów?”**  
  Tak, parametrem startowym serwisu `-e` (wymaga restartu).
- **„Gdzie są deadlocki?”**  
  Pełny graf w **Extended Events / system_health**; w ERRORLOG tylko wzmianka.
- **„A co z historią jobów?”**  
  `msdb.dbo.sysjobhistory` + log kroków (jeśli włączony „Log to table” w definicji kroku).

---


