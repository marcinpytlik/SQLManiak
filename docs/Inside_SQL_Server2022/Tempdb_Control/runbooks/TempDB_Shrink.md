# Runbook: TempDB_Shrink (SQL Server 2019)

## 🎯 Cel
Kontrolowane zmniejszenie rozmiaru plików **tempdb** (DATA i LOG), bez wpadania w pętlę autogrow, z zachowaniem bezpieczeństwa i wydajności.

---

## 🔒 Warunki wstępne
- Uprawnienia: `sysadmin`.
- Okno serwisowe lub niska aktywność (DEV — może być „na żywo”, PROD — poza godzinami).
- Ścieżki i nazwy plików `tempdb` znane (patrz sekcja „Inwentaryzacja”).
- Świadomość blokera: **version store** (SI/RCSI) i trwające operacje mogą uniemożliwiać shrink.
- W DEV: **nie** używamy `DBCC SHRINKDATABASE` — tylko **`DBCC SHRINKFILE`**.

---

## 🧭 Parametry (dostosuj pod środowisko)
- Docelowy rozmiar DATA (na plik): `4–8 GB` (przykład).
- Docelowy rozmiar LOG: `1–2 GB` (przykład).
- FILEGROWTH:
  - DATA: `512 MB`
  - LOG: `256 MB`
- Liczba plików DATA: zwykle `4–8`, równe rozmiary.

> Uwaga: wartości przykładowe — dopasuj do obciążenia i pamięci/dysku.

---

## 🧪 Krok 0 — Inwentaryzacja i diagnoza

```sql
-- 0.1 Rozmiary i autogrowth tempdb
USE tempdb;
SELECT name AS logical_name, type_desc, size*8/1024 AS size_MB, growth, is_percent_growth, physical_name
FROM sys.database_files
ORDER BY type_desc, name;

-- 0.2 Użycie przestrzeni w tempdb (MB)
SELECT
  SUM(user_object_reserved_page_count)*8/1024  AS user_MB,
  SUM(internal_object_reserved_page_count)*8/1024 AS internal_MB,
  SUM(version_store_reserved_page_count)*8/1024  AS version_store_MB,
  SUM(unallocated_extent_page_count)*8/1024      AS free_MB
FROM sys.dm_db_file_space_usage;

-- 0.3 Długie snapshoty (czytelnicy blokujący version store)
SELECT TOP(20)
  transaction_id, elapsed_time_seconds, database_id, is_snapshot
FROM sys.dm_tran_active_snapshot_database_transactions
ORDER BY elapsed_time_seconds DESC;
```

**Interpretacja:**
- Jeśli `version_store_MB` jest duże i są wiersze w 0.3 → znajdź i zamknij długie snapshoty.
- Jeśli `internal_MB` jest duże → trwają złożone operacje (sort/hash/spool) — zaczekaj lub zatrzymaj zadanie.

---

## 🧹 Krok 1 — „Odklejenie” przestrzeni

```sql
-- 1.1 Sesje z długimi transakcjami (do przeglądu)
SELECT s.session_id, s.login_name, s.host_name, s.program_name,
       DATEDIFF(MINUTE, at.transaction_begin_time, SYSDATETIME()) AS min_open
FROM sys.dm_tran_active_transactions at
JOIN sys.dm_tran_session_transactions st ON st.transaction_id = at.transaction_id
JOIN sys.dm_exec_sessions s ON s.session_id = st.session_id
WHERE at.transaction_type IN (1,2) -- RW/RO
  AND s.is_user_process = 1
ORDER BY min_open DESC;

-- 1.2 (opcjonalnie w DEV) zakończ wybrane SPID:
-- KILL <spid>;
```

> W większości przypadków zamknięcie „zombie” snapshotów wystarcza, by shrink zadziałał.

---

## 🔧 Krok 2 — Ustaw autogrowth w MB (zanim zmniejszysz)

```sql
USE tempdb;
-- DOPASUJ nazwy logiczne do swoich plików!
ALTER DATABASE tempdb MODIFY FILE (NAME = N'tempdev',  FILEGROWTH = 512MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = N'tempdev2', FILEGROWTH = 512MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = N'tempdev3', FILEGROWTH = 512MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = N'tempdev4', FILEGROWTH = 512MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = N'templog',  FILEGROWTH = 256MB);
```

---

## ✂️ Krok 3 — Shrink DATA i LOG do docelowych rozmiarów

```sql
USE tempdb;
-- Przykładowe cele: DATA 4096 MB/plik, LOG 2048 MB

DBCC SHRINKFILE (N'tempdev',  4096);
DBCC SHRINKFILE (N'tempdev2', 4096);
DBCC SHRINKFILE (N'tempdev3', 4096);
DBCC SHRINKFILE (N'tempdev4', 4096);

DBCC SHRINKFILE (N'templog',  2048);

-- Weryfikacja
SELECT name, size*8/1024 AS size_MB FROM sys.database_files ORDER BY type_desc, name;
```

**Notatki:**
- `DBCC SHRINKFILE` działa w MB. Jeśli nie schodzi — wróć do Krok 1 i sprawdź snapshoty/operacje.
- `EMPTYFILE` dla tempdb jest ignorowane — usuwanie plików wymaga zwykle restartu instancji.

---

## 🔁 Krok 4 — (Opcjonalnie) Restart instancji
Jeśli:
- brak snapshotów i dużych operacji,
- a shrink nadal nie uwalnia przestrzeni,

zaplanuj **kontrolowany restart** (tempdb tworzy się od nowa).

---

## ✅ Krok 5 — Weryfikacja po operacji

```sql
-- 5.1 Rozmiary plików tempdb
SELECT name, type_desc, size*8/1024 AS size_MB, growth, is_percent_growth
FROM sys.database_files
ORDER BY type_desc, name;

-- 5.2 Użycie przestrzeni po shrinku
SELECT
  SUM(user_object_reserved_page_count)*8/1024  AS user_MB,
  SUM(internal_object_reserved_page_count)*8/1024 AS internal_MB,
  SUM(version_store_reserved_page_count)*8/1024  AS version_store_MB,
  SUM(unallocated_extent_page_count)*8/1024      AS free_MB
FROM sys.dm_db_file_space_usage;
```

Checklist:
- [ ] Pliki DATA mają **równe** rozmiary i oczekiwane wartości.
- [ ] LOG ma oczekiwany rozmiar.
- [ ] FILEGROWTH ustawione w **MB**.
- [ ] Brak lawiny autogrow w godzinach po operacji.

---

## 🧯 Rollback / Przywrócenie rozmiarów
Jeśli po shrinku występują częste autogrow lub spadek wydajności:
```sql
-- Ustal stabilny rozmiar bazowy (np. 6–8 GB/plik DATA, 2–4 GB LOG) i powiększ:
USE master;
ALTER DATABASE tempdb MODIFY FILE (NAME = N'tempdev',  SIZE = 6144MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = N'tempdev2', SIZE = 6144MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = N'tempdev3', SIZE = 6144MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = N'tempdev4', SIZE = 6144MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = N'templog',  SIZE = 3072MB);
```

---

## 📈 Monitoring po akcji
- Trend autogrow i version store (z naszych jobów):
  ```sql
  SELECT * FROM DBA.dbo.vAutogrowHourly_24h;
  SELECT * FROM DBA.dbo.vVersionStore15min;
  ```
- Długie snapshoty:
  ```sql
  SELECT TOP(20) transaction_id, elapsed_time_seconds, database_id
  FROM sys.dm_tran_active_snapshot_database_transactions
  ORDER BY elapsed_time_seconds DESC;
  ```

---

## 📝 Uwagi operacyjne
- **Nie** rób `DBCC SHRINKDATABASE` w tempdb.
- Shrink to **jednorazowa korekta**, nie codzienna rutyna. Przywróć sensowny **initial size** i **FILEGROWTH**.
- Główne przyczyny puchnięcia:
  - długie snapshoty (SI/RCSI),
  - duże sorty/hash/spool, spill operatorów.
- Zmniejszanie liczby plików tempdb: najstabilniejsze **po restarcie**:
  1) Zmniejsz pliki do małych rozmiarów,  
  2) `ALTER DATABASE tempdb REMOVE FILE <tempdevX>`,  
  3) Restart serwisu SQL Server.
