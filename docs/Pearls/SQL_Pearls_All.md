
# SQLManiak Pearls – Vol.1 (zbiorczo)

Poniżej komplet treści 10 perełek. Każda z nich jest również dostępna jako osobny plik w tym folderze.


---


# 01 – DELETE vs TRUNCATE

**Idea:** Oba usuwają dane, ale robią to na innym poziomie i z innymi konsekwencjami dla logu i metadanych.

## Setup (lab)
```sql
USE tempdb;
GO
IF OBJECT_ID('dbo.DemoDeleteTruncate') IS NOT NULL DROP TABLE dbo.DemoDeleteTruncate;
CREATE TABLE dbo.DemoDeleteTruncate
(
    Id INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    Category INT NOT NULL,
    Payload CHAR(100) NULL
);

INSERT INTO dbo.DemoDeleteTruncate(Category, Payload)
SELECT TOP (100000) ABS(CHECKSUM(NEWID())) % 100, 'x'
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
DBCC SQLPERF(LOGSPACE); -- zapisz rozmiar tempdb log
```

## Test
```sql
-- DELETE (wiersz po wierszu – pełne logowanie)
BEGIN TRAN;
DELETE FROM dbo.DemoDeleteTruncate WHERE Category = 7;
ROLLBACK;

-- TRUNCATE (dealokacja całych stron/extentów, reset IDENTITY)
TRUNCATE TABLE dbo.DemoDeleteTruncate;
```

## Obserwacje
- `DELETE`: loguje każdą usuniętą krotkę; nie resetuje `IDENTITY`.
- `TRUNCATE`: loguje de‑alokacje stron; **resetuje `IDENTITY`**; wymaga braku FK na tabelę.

## Weryfikacja
```sql
DBCC CHECKIDENT ('dbo.DemoDeleteTruncate', NORESEED);
SELECT log_reuse_wait, log_reuse_wait_desc FROM sys.databases WHERE name = 'tempdb';
```

## Wnioski
- `TRUNCATE` jest szybszy i lżejszy dla logu, ale ma ograniczenia.
- `DELETE` daje kontrolę (filtry, trigger AFTER DELETE), ale generuje większy log.


---


# 02 – Ghost Cleanup

**Idea:** Po `DELETE` wiersze stają się „ghosts” (oznaczone do usunięcia). Proces **Ghost Cleanup** fizycznie sprząta je w tle.

## Setup
```sql
USE tempdb;
GO
IF OBJECT_ID('dbo.DemoGhost') IS NOT NULL DROP TABLE dbo.DemoGhost;
CREATE TABLE dbo.DemoGhost (Id INT IDENTITY PRIMARY KEY, Payload CHAR(200));
INSERT INTO dbo.DemoGhost(Payload) SELECT TOP (50000) 'x' FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
```

## Test
```sql
DELETE TOP (40000) FROM dbo.DemoGhost; -- dużo ghostów
CHECKPOINT;
```

## Podgląd (poziom DMV)
```sql
SELECT * FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('dbo.DemoGhost'), NULL, NULL, 'DETAILED');
-- poszukaj stron z dużą liczbą usuniętych rekordów

-- aktywność procesu
SELECT * 
FROM sys.dm_exec_requests 
WHERE command IN ('GHOST CLEANUP','TASK MANAGER'); -- wskaźnikowo
```

## Wnioski
- Ghost cleanup działa opportunistycznie – może się „spóźniać” przy dużym obciążeniu.
- Skany mogą omijać ghosty, ale nadal „płacisz” za ich obecność na stronach (fragmentacja).


---


# 03 – SPID < 50

**Idea:** SPID mniejsze niż 50 to wewnętrzne procesy systemowe: LOG WRITER, LAZY WRITER, RESOURCE MONITOR itd.

## Podgląd
```sql
SELECT s.session_id, s.login_name, s.status, r.command, r.wait_type, r.cpu_time, r.total_elapsed_time
FROM sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r ON s.session_id = r.session_id
WHERE s.session_id < 50
ORDER BY s.session_id;
```

## Ciekawostka
- Nie „zabijaj” tych sesji. To wbudowane usługi silnika.
- Zdarza się zobaczyć GHOST CLEANUP, CHECKPOINT, DB STARTUP/SHUTDOWN.


---


# 04 – Statystyki bez indeksu („pseudo‑indeks”)

**Idea:** Optymalizator może oprzeć estymacje na **histogramie statystyki** nawet bez fizycznego indeksu.

## Setup
```sql
USE tempdb;
GO
IF OBJECT_ID('dbo.DemoStats') IS NOT NULL DROP TABLE dbo.DemoStats;
CREATE TABLE dbo.DemoStats (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Category INT,
    Payload CHAR(100) DEFAULT 'x'
);
INSERT INTO dbo.DemoStats(Category)
SELECT TOP (100000) ABS(CHECKSUM(NEWID())) % 1000
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
CREATE STATISTICS Stats_Category ON dbo.DemoStats(Category);
GO
```

## Test
```sql
SET STATISTICS XML ON;
SELECT COUNT(*) AS Cnt FROM dbo.DemoStats WHERE Category = 777;
SET STATISTICS XML OFF;
```

## Analiza
- W planie sprawdź **Estimated Number of Rows** – zgodność pochodzi z histogramu statystyki.
- Fizycznie to nadal skan tabeli/hoBT, ale estymacja bywa trafna jak przy indeksie.

## Wniosek
- Dobra statystyka potrafi „uratować” plan. To nie zastąpi indeksu, ale bywa zaskakująco skuteczne.


---


# 05 – Auto Update / Async Stats

**Idea:** Statystyki nie aktualizują się „zawsze i wszędzie”. Liczy się próg zmian i tryb Async.

## Setup
```sql
USE tempdb; 
GO
IF OBJECT_ID('dbo.DemoAutoStats') IS NOT NULL DROP TABLE dbo.DemoAutoStats;
CREATE TABLE dbo.DemoAutoStats (Id INT IDENTITY PRIMARY KEY, K INT NOT NULL);
INSERT INTO dbo.DemoAutoStats(K) SELECT TOP (100000) 1 FROM sys.all_objects a CROSS JOIN sys.all_objects b;
CREATE STATISTICS S_K ON dbo.DemoAutoStats(K);
```

## Test progu
```sql
-- Modyfikujemy ~20% wierszy; próg dla dużych tabel to ~20% + 500 wierszy (dla starszych CE).
UPDATE TOP (25000) dbo.DemoAutoStats SET K = 2;
GO
-- sprawdź, czy zaktualizowano statystyki
SELECT name, STATS_DATE(object_id, stats_id) AS stats_date
FROM sys.stats WHERE object_id = OBJECT_ID('dbo.DemoAutoStats');
```

## Async?
```sql
EXEC sp_autostats 'dbo.DemoAutoStats', 'ON'; -- auto update włączone
ALTER DATABASE SCOPED CONFIGURATION SET ASYNCHRONOUS_STATS_UPDATE = ON; -- async
```

## Wnioski
- Przy async pierwsze zapytanie korzysta ze starych statystyk, a aktualizacja leci w tle.
- Progi i heurystyki zależą od CE (Cardinality Estimator) i wersji SQL.


---


# 06 – Tempdb Allocations

**Idea:** Zrozumienie alokacji w tempdb (PFS/GAM/SGAM) pomaga przy zakleszczeniach i hotspotach alokacyjnych.

## Setup
```sql
USE tempdb;
GO
IF OBJECT_ID('dbo.DemoTemp') IS NOT NULL DROP TABLE dbo.DemoTemp;
CREATE TABLE dbo.DemoTemp (Id INT IDENTITY, Pad CHAR(4000) DEFAULT 'x');
GO
```

## Test równoległy (uruchom w kilku sesjach)
```sql
INSERT INTO dbo.DemoTemp DEFAULT VALUES;
GO 10000
```

## Podgląd alokacji
```sql
SELECT * 
FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('dbo.DemoTemp'), NULL, NULL, 'DETAILED');
```

## Wnioski
- Wielowątkowe inserty w małe strony mogą tworzyć hotspoty na PFS.
- Więcej plików tempdb (np. 1 plik na 4 rdzenie, max 8) pomaga rozproszyć alokacje.


---


# 07 – PFS / GAM / SGAM

**Idea:** Strony kontrolne śledzą zajętość i wolne extenty. Zrozum je, a zrozumiesz „skąd ten wait”.

- **PFS (Page Free Space)**: ile wolnego miejsca na stronie (alokacje wierszy).
- **GAM (Global Allocation Map)**: które extenty są wolne.
- **SGAM (Shared GAM)**: które extenty mają wolne strony (mixed).

## Ścieżka do diagnostyki
```sql
DBCC TRACEON(3604);
DBCC PAGE (DB_ID(), 1, 1, 3);   -- PFS strona (przykład; adres zależy od DB)
DBCC PAGE (DB_ID(), 2, 1, 3);   -- GAM
DBCC PAGE (DB_ID(), 3, 1, 3);   -- SGAM
```

**Uwaga:** DBCC PAGE jest nieudokumentowane; używaj w labie/testach.


---


# 08 – RCSI / Snapshot – wersjonowanie

**Idea:** Przy RCSI/SI wersje wierszy trafiają do tempdb. To zmienia blokady i wpływa na log/truncation.

## Setup
```sql
USE tempdb;
GO
ALTER DATABASE tempdb SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO

IF OBJECT_ID('dbo.DemoRCSI') IS NOT NULL DROP TABLE dbo.DemoRCSI;
CREATE TABLE dbo.DemoRCSI (Id INT IDENTITY PRIMARY KEY, Val INT);
INSERT INTO dbo.DemoRCSI(Val) VALUES (1),(2),(3),(4),(5);
GO
```

## Test (2 sesje)
- **Sesja A**
```sql
BEGIN TRAN;
UPDATE dbo.DemoRCSI SET Val = Val + 1 WHERE Id <= 5;
-- Nie commituj od razu
```

- **Sesja B**
```sql
SELECT * FROM dbo.DemoRCSI; -- przy RCSI czyta wersje bez blokowania A
```

## Wnioski
- Mniej blokad czytających, ale dodatkowy koszt wersjonowania (tempdb, log).
- Długie snapshoty mogą trzymać stare wersje i blokować `log truncation`.


---


# 09 – Log Truncation

**Problem:** Plik logu nie maleje mimo SHRINK.

## Szybka diagnostyka
```sql
USE tempdb;
GO
DBCC SQLPERF(LOGSPACE);
SELECT name, recovery_model_desc, log_reuse_wait, log_reuse_wait_desc
FROM sys.databases
WHERE name = 'tempdb';
```

**Typowe przyczyny:**
- aktywna transakcja (w tym długi snapshot/RCSI),
- brak CHECKPOINT,
- brak backupu logu (FULL/BULK_LOGGED),
- replikacja, CDC, AlwaysOn AG (HADR).

## Procedura
1) Znajdź blokera:
```sql
SELECT session_id, open_transaction_count FROM sys.dm_exec_sessions WHERE is_user_process = 1;
DBCC OPENTRAN;
```
2) Wymuś CHECKPOINT / backup logu (pełne modele).  
3) Dopiero potem `DBCC SHRINKFILE(log, <target MB>)`.

**Wniosek:** SHRINK to kosmetyka po **truncation**. Nie zamiast.


---


# 10 – ARIES i Page Restore

**Idea:** Model ARIES (Write‑Ahead Logging + Redo/Undo) pozwala na **partial/page restore** po uszkodzeniu strony.

## Demo śladowe (koncepcja – bez psucia stron w produkcji)
```sql
-- Załóżmy backup FULL + sekwencja logów.
-- Przy uszkodzeniu strony:
RESTORE DATABASE DemoDB PAGE = '1:12345' 
FROM DISK = 'DemoDB_full.bak'
WITH NORECOVERY;

RESTORE LOG DemoDB FROM DISK = 'DemoDB_log1.trn' WITH NORECOVERY;
RESTORE LOG DemoDB FROM DISK = 'DemoDB_log2.trn' WITH RECOVERY;
```

## Wnioski
- Page restore skraca RTO przy lokalnym uszkodzeniu danych.
- ARIES gwarantuje spójność przez log redo/undo.
