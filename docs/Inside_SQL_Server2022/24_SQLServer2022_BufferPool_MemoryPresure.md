To jedno z tych miejsc, gdzie SQL Server pokazuje, jak fizyczna pamięć staje się logiczną strukturą danych.

---

## 🔍 1️⃣ Najprostsze i najszybsze – ile każda baza zajmuje w Buffer Poolu

Ten kod zlicza ilość stron (8 KB) z `sys.dm_os_buffer_descriptors` i grupuje po `database_id`:

```sql
-- 🧠 Zużycie Buffer Pool per baza danych
SELECT
    DB_NAME(database_id) AS DatabaseName,
    COUNT(*) AS PageCount,
    COUNT(*) * 8 / 1024 AS BufferPool_MB
FROM sys.dm_os_buffer_descriptors
WHERE database_id NOT IN (32767)  -- pomijamy ResourceDB
GROUP BY DB_NAME(database_id)
ORDER BY BufferPool_MB DESC;
```

📊 **Co pokazuje:**

- `PageCount` → liczba stron 8KB w pamięci,  
- `BufferPool_MB` → przybliżony rozmiar w MB,  
- Pomija `database_id = 32767` (Resource DB, zawsze rezydentna).

---

## 🧩 2️⃣ Rozbicie na typy danych (DATA / INDEX / IAM / itp.)

Jeśli chcesz dokładniej zobaczyć, co dana baza trzyma w pamięci:

```sql
-- 🔬 Rozbicie na typy stron
SELECT
    DB_NAME(database_id) AS DatabaseName,
    page_type,
    COUNT(*) AS PageCount,
    COUNT(*) * 8 / 1024 AS BufferPool_MB
FROM sys.dm_os_buffer_descriptors
WHERE database_id NOT IN (32767)
GROUP BY DB_NAME(database_id), page_type
ORDER BY DatabaseName, BufferPool_MB DESC;
```

Dzięki temu zobaczysz np. że `AdventureWorks` ma 150 MB stron danych i 30 MB stron indeksowych.

---

## ⚙️ 3️⃣ Procentowy udział pamięci w Buffer Poolu

```sql
-- 📈 Procentowy udział pamięci w Buffer Poolu
WITH Buffers AS (
    SELECT
        DB_NAME(database_id) AS DatabaseName,
        COUNT(*) * 8 / 1024.0 AS BufferPool_MB
    FROM sys.dm_os_buffer_descriptors
    WHERE database_id NOT IN (32767)
    GROUP BY DB_NAME(database_id)
)
SELECT
    DatabaseName,
    BufferPool_MB,
    BufferPool_MB * 100.0 / SUM(BufferPool_MB) OVER() AS PercentOfTotal
FROM Buffers
ORDER BY BufferPool_MB DESC;
```

Świetne do szybkiego wglądu: np. „baza `ReportDB` zajmuje 72% bufora”.

---

## 🧠 4️⃣ Co warto wiedzieć

- To jest stan **chwili**, nie średnia — dane z DMV są „live”.  
- Jeśli wykonasz `DBCC DROPCLEANBUFFERS`, liczby spadną (czyści Buffer Pool).  
- W środowisku z dużą liczbą baz (multi-tenant) to jedyne realne źródło prawdziwego zużycia pamięci per baza.  
- W SQL Server 2019+ możesz korelować to z `sys.dm_os_memory_clerks` (typ `MEMORYCLERK_SQLBUFFERPOOL`).

---

## 🧩 5️⃣ Bonus – ostatnie użycie stron

```sql
SELECT
    DB_NAME(database_id) AS DatabaseName,
    COUNT(*) AS PageCount,
    COUNT(*) * 8 / 1024 AS BufferPool_MB,
    MAX(free_space_in_bytes) AS MaxFreeBytes
FROM sys.dm_os_buffer_descriptors
WHERE database_id NOT IN (32767)
GROUP BY DB_NAME(database_id)
ORDER BY BufferPool_MB DESC;
```

---

## 🧭 Presja na pamięć – jak ją zmierzyć

„Ile RAM-u zużywa SQL” to jedno, a „czy mu go brakuje” to zupełnie inna historia.  
Tę presję można zmierzyć konkretnie — zarówno z poziomu silnika, jak i Windowsa.

---

## 🧠 1️⃣ Page Life Expectancy (PLE) – termometr SQL Servera

```sql
SELECT 
    [object_name], 
    [counter_name], 
    [cntr_value] AS PageLifeExpectancy_sec
FROM sys.dm_os_performance_counters
WHERE [counter_name] = 'Page life expectancy';
```

📊 **Interpretacja:**

- `PLE` = ile sekund przeciętnie strona pozostaje w pamięci zanim zostanie wyrzucona.  
- Im niższe, tym większa presja.  
- Na serwerach 2019–2022 z dużą pamięcią:  
  - > 3000–5000 → dobrze,  
  - 500–1000 → średnia presja,  
  - < 300 → duża presja.  

(Uwaga: od SQL 2012 każdy NUMA node ma swój własny PLE — warto zgrupować po `object_name`.)

---

## ⚙️ 2️⃣ Faktyczne zużycie pamięci przez instancję

```sql
SELECT 
    physical_memory_in_use_kb / 1024 AS MemoryUsed_MB,
    locked_page_allocations_kb / 1024 AS LockedPages_MB,
    total_virtual_address_space_kb / 1024 AS VirtualSpace_MB,
    process_physical_memory_low AS IsLowMemory,
    process_virtual_memory_low AS IsVirtualLowMemory
FROM sys.dm_os_process_memory;
```

📊 **Interpretacja:**

- `MemoryUsed_MB` – ile RAM faktycznie trzyma SQL.  
- `IsLowMemory = 1` → presja (systemowy sygnał niskiej pamięci).  
- `LockedPages_MB` → ile zarezerwowane przez „Lock Pages in Memory”.

---

## 🧩 3️⃣ Memory Grants – presja przy zapytaniach

```sql
SELECT 
    COUNT(*) AS ActiveMemoryGrants,
    SUM(requested_memory_kb)/1024 AS Requested_MB,
    SUM(granted_memory_kb)/1024 AS Granted_MB,
    SUM(used_memory_kb)/1024 AS Used_MB
FROM sys.dm_exec_query_memory_grants
WHERE grant_time IS NULL OR grant_time > DATEADD(MINUTE, -1, GETDATE());
```

📊 **Interpretacja:**

- `Requested_MB >> Granted_MB` → zapytania czekają na pamięć (*memory grant wait*).  
- Dużo aktywnych grantów → presja w „workspace memory”.  
- Często towarzyszy temu `RESOURCE_SEMAPHORE` w `sys.dm_exec_requests.wait_type`.

---

## ⚙️ 4️⃣ Ogólna presja na Buffer Pool

```sql
SELECT 
    (cntr_value) AS FreeListStallsPerSec
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Free list stalls/sec';
```

📊 **Interpretacja:**

- Pokazuje, ile razy serwer **czekał na wolną stronę w buforze**.  
- `> 0` oznacza presję.  
- Im większa liczba, tym bardziej brakuje wolnych stron w Buffer Poolu.

---

## 🧮 5️⃣ Równowaga między plan cache a buffer pool

SQL często walczy o pamięć między **plan cache** (execution plans) a **buffer pool** (dane).

```sql
SELECT type, SUM(pages_kb)/1024 AS Size_MB
FROM sys.dm_os_memory_clerks
WHERE type IN ('CACHESTORE_SQLCP','CACHESTORE_OBJCP','MEMORYCLERK_SQLBUFFERPOOL')
GROUP BY type
ORDER BY Size_MB DESC;
```

📊 **Interpretacja:**

- `CACHESTORE_SQLCP` – ad-hoc plany,  
- `CACHESTORE_OBJCP` – procedury,  
- `MEMORYCLERK_SQLBUFFERPOOL` – dane i indeksy.  
Jeśli plan cache „zjada” więcej niż buffer pool → presja na dane.

---

## 🧰 6️⃣ Z poziomu Windows

Szybka diagnostyka PowerShell / perfmon:

```powershell
Get-Counter '\Memory\Available MBytes'
Get-Counter '\SQLServer:Memory Manager\Total Server Memory (KB)'
Get-Counter '\SQLServer:Memory Manager\Target Server Memory (KB)'
```

📊 **Interpretacja:**

- `Total < Target` → SQL chce więcej RAMu → presja.  
- `Total ≈ Target` → SQL dostał, czego potrzebuje → stabilnie.

---

## 🧭 7️⃣ Raport SQLManiaka – Memory Pressure Snapshot

```sql
SELECT
  (SELECT cntr_value FROM sys.dm_os_performance_counters WHERE counter_name='Page life expectancy') AS PLE,
  (SELECT cntr_value FROM sys.dm_os_performance_counters WHERE counter_name='Free list stalls/sec') AS FreeListStallsPerSec,
  (SELECT physical_memory_in_use_kb FROM sys.dm_os_process_memory)/1024 AS MemoryUsed_MB,
  (SELECT total_server_memory_kb FROM sys.dm_os_sys_memory)/1024 AS TotalServerMemory_MB,
  (SELECT target_server_memory_kb FROM sys.dm_os_sys_memory)/1024 AS TargetServerMemory_MB;
```

📈 Wynik pokaże w jednym rzucie, **czy serwer jest syty, czy głodny.**

---

> „Kiedy Buffer Pool się poci, SQL Server nie potrzebuje więcej CPU.  
> Potrzebuje więcej oddechu — czyli pamięci.”  
> — *SQLManiak – Anatomia bufora*

---
