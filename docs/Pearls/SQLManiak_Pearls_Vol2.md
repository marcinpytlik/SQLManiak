# SQLManiak Pearls – Vol.2 (zbiorczo)

Poniżej komplet 10 nowych perełek. 

---

## 01 – Ghost Records: życie po DELETE

**Idea:** Usunięte wiersze nie znikają od razu — stają się *ghost records*, dopóki *Ghost Cleanup Task* nie przeprowadzi egzorcyzmu.

**Setup**
```sql
USE tempdb;
GO
IF OBJECT_ID('dbo.DemoGhost') IS NOT NULL DROP TABLE dbo.DemoGhost;
CREATE TABLE dbo.DemoGhost(Id INT IDENTITY PRIMARY KEY, Data CHAR(200));
INSERT INTO dbo.DemoGhost DEFAULT VALUES;
GO 50000
```

**Test**
```sql
DELETE TOP (40000) FROM dbo.DemoGhost;
GO
DBCC CHECKTABLE('dbo.DemoGhost') WITH TABLERESULTS;
```

**Obserwacje**
- W kolumnie `GhostRecCnt` zobaczysz liczbę duchów.  
- Proces *Ghost Cleanup* działa asynchronicznie.  
- Zdarza się opóźnienie, zwłaszcza przy snapshot isolation.

**Wnioski**
- Ghost records to gwarancja bezpieczeństwa dla rollbacków.  
- To, że wiersza nie widać, nie znaczy, że go nie ma.

---

## 02 – Buffer Pool: kto trzyma Twoje strony

**Idea:** Buffer Pool to pamięć, w której SQL Server przechowuje strony 8KB. Wiedza o tym, co w nim siedzi, pozwala rozumieć I/O.

**Podgląd**
```sql
SELECT COUNT(*) AS Cached_Pages,
       (COUNT(*)*8)/1024 AS MB_Cached,
       OBJECT_NAME(p.object_id) AS TableName
FROM sys.dm_os_buffer_descriptors AS p
WHERE database_id = DB_ID()
GROUP BY p.object_id
ORDER BY MB_Cached DESC;
```

**Wnioski**
- Strony najczęściej używanych tabel zostają w pamięci.
- Przy dużych I/O można obserwować "evictions" – wyparte strony.
- Pamięć SQL to nie czarna skrzynka — to żywy ekosystem.

---

## 03 – THREADPOOL Waits: gdy serwer kończy wątki

**Idea:** THREADPOOL oznacza brak dostępnych workerów — zjawisko rzadkie, ale krytyczne.

**Diagnoza**
```sql
SELECT * FROM sys.dm_os_schedulers WHERE current_tasks_count > active_workers_count;
SELECT * FROM sys.dm_exec_requests WHERE wait_type = 'THREADPOOL';
```

**Wnioski**
- Zbyt wiele równoczesnych zapytań.
- Zbyt mało wątków (MAXDOP, liczba schedulerów).
- Często wynik złego kodu aplikacji – tysiące połączeń zamiast puli.

---

## 04 – Parameter Sensitive Plan (PSP) Optimization

**Idea:** W SQL Server 2022 optymalizator potrafi utrzymywać kilka planów dla różnych zakresów parametrów.

**Demo**
```sql
CREATE OR ALTER PROC dbo.PSPDemo @Category INT AS
SELECT * FROM Sales.SalesOrderDetail WHERE ProductID = @Category;
GO
EXEC dbo.PSPDemo 870;  -- mało wierszy
EXEC dbo.PSPDemo 776;  -- dużo wierszy
```

**Obserwacje**
```sql
SELECT * FROM sys.dm_exec_cached_plans
WHERE objtype = 'Proc' AND cacheobjtype = 'Compiled Plan';
```

**Wnioski**
- PSP redukuje problem „parameter sniffing”.
- SQL Server może utrzymywać kilka planów jednocześnie.
- To adaptacja w praktyce, nie magia.

---

## 05 – Resource Governor: kontrola chaosu

**Idea:** RG pozwala ograniczyć zasoby dla grup użytkowników — CPU, I/O, pamięć.

**Setup**
```sql
CREATE RESOURCE POOL PoolApp WITH (MAX_CPU_PERCENT = 30);
CREATE WORKLOAD GROUP WG_App USING PoolApp;
ALTER RESOURCE GOVERNOR RECONFIGURE;
```

**Klasyfikator**
```sql
CREATE FUNCTION dbo.RGClassifier()
RETURNS SYSNAME
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE WHEN APP_NAME() LIKE '%AppX%' THEN 'WG_App' END;
END;
GO
ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = dbo.RGClassifier);
ALTER RESOURCE GOVERNOR RECONFIGURE;
```

**Wnioski**
- Klasyfikuj według `APP_NAME()`, `HOST_NAME()`, loginu.
- RG to nie tylko ograniczanie, ale i izolacja obciążeń.

---

## 06 – Instant File Initialization (IFI)

**Idea:** Przy włączonym IFI SQL nie zeruje plików danych przy tworzeniu lub rozszerzaniu.

**Weryfikacja**
```sql
EXEC xp_cmdshell 'whoami /priv';
```
Szukaj `SeManageVolumePrivilege` (dla konta SQL Servera).

**Wnioski**
- IFI przyspiesza tworzenie i restore.
- Nie działa dla plików logów (zawsze pełne zerowanie).
- Warto, ale tylko na zaufanych systemach.

---

## 07 – Query Store: pamięć planów

**Idea:** Query Store śledzi historię zapytań, planów i wydajności.

**Setup**
```sql
ALTER DATABASE [AdventureWorks2022] SET QUERY_STORE = ON;
```

**Analiza**
```sql
SELECT TOP 10 query_text_id, plan_id, avg_duration, count_executions
FROM sys.query_store_runtime_stats;
```

**Wnioski**
- QS to „czarna skrzynka” planów.
- Umożliwia forcing planów i analizę trendów.
- Idealne narzędzie po zmianie wersji lub CE.

---

## 08 – Log Sequence Number (LSN)

**Idea:** LSN to punkt w czasie w logu transakcyjnym – podstawowa oś czasu ARIES.

**Podgląd**
```sql
SELECT TOP 10 [Current LSN], Operation, Context, [Transaction ID]
FROM fn_dblog(NULL,NULL);
```

**Wnioski**
- Każdy LSN to logiczny „moment” w historii bazy.
- Recovery zna porządek: analysis → redo → undo.
- Zrozumienie LSN to zrozumienie, jak SQL pamięta.

---

## 09 – Always Encrypted vs TDE

**Idea:** Oba szyfrują dane, ale na różnych warstwach.

**Porównanie**
| Mechanizm | Zakres | Kto widzi dane odszyfrowane | Klucze |
|------------|--------|-----------------------------|--------|
| **TDE** | Cała baza | SQL Server | Certyfikat w master |
| **Always Encrypted** | Kolumny | Aplikacja (po stronie klienta) | Master Key + Column Key |

**Wnioski**
- TDE chroni plik; AE chroni dane przed adminem.
- AE wymaga wsparcia po stronie aplikacji.
- Oba razem mogą współistnieć.

---

## 10 – Extended Events: lekkie śledzenie

**Idea:** XE to nowoczesny, lekki następca Profiler’a.

**Setup**
```sql
CREATE EVENT SESSION [QueryMonitor] ON SERVER
ADD EVENT sqlserver.sql_statement_completed
(
    ACTION (sqlserver.client_app_name, sqlserver.database_name)
    WHERE (duration > 1000000)
)
ADD TARGET package0.event_file (SET filename = 'C:\XE\QueryMonitor.xel');
ALTER EVENT SESSION [QueryMonitor] ON SERVER STATE = START;
```

**Wnioski**
- XE działa asynchronicznie — nie blokuje.
- Można filtrować, agregować i analizować w czasie rzeczywistym.
- To must-have w każdym warsztacie DBA.
