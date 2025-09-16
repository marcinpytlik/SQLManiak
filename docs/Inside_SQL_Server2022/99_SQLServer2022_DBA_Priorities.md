# 🧭 Mapa priorytetów DBA – SQL Server 2022

---

## ✅ Co DBA powinien wiedzieć z pamięci (operacyjne „must know”) według mnie

1. **Podstawy T-SQL**  
   - SELECT / INSERT / UPDATE / DELETE  
   - JOIN, GROUP BY, HAVING, ORDER BY  
   - Transakcje (`BEGIN/COMMIT/ROLLBACK`)

2. **Backup/Restore**  
   - FULL, DIFF, LOG – kolejność i zależności  
   - Jak sprawdzić ostatni backup (`msdb.dbo.backupset`)  
   - `RESTORE WITH NORECOVERY` vs `RECOVERY`

3. **Tryby odzyskiwania (Recovery Models)**  
   - SIMPLE, FULL, BULK_LOGGED  
   - Co oznaczają dla logów i backupów

4. **Podstawowe DMV do diagnozy**  
   - `sys.dm_exec_requests` (bieżące zapytania)  
   - `sys.dm_exec_sessions` (sesje)  
   - `sys.dm_exec_query_stats` (historia planów)  
   - `sys.dm_os_wait_stats` (wait types)

5. **Wait types i blokady**  
   - Co oznacza `LCK_M_X`, `PAGEIOLATCH`, `CXPACKET`, `SOS_SCHEDULER_YIELD`

6. **Najczęstsze komunikaty błędów**  
   - 9002 (log pełny)  
   - 823/824 (I/O error)  
   - 17883 (scheduler deadlock)  

---

## 📚 Co wystarczy mieć w dokumentacji

1. **Internals**  
   - Typy stron, extentów, struktura plików  
   - Kolejność stron PFS/GAM/DCM/BCM  
   - Budowa logu (VLF, LSN)

2. **Szczegółowe typy danych i zakresy**  
   - Ile bajtów zajmuje każdy typ  
   - Różnice collation i kodowania  
   - Typy CLR (geometry, geography, hierarchyid)

3. **Rzadkie funkcjonalności**  
   - Filestream  
   - In-Memory OLTP szczegóły  
   - Temporal + Graph tables

4. **Zaawansowane narzędzia**  
   - DBCC PAGE, DBCC IND, DBCC CHECKDB  
   - SQLDump, SQLDiag, Extended Events konfiguracje

5. **Procedury operacyjne**  
   - Runbooki do AlwaysOn / FCI  
   - Skrypty monitoringowe  
   - Instrukcje instalacyjne krok po kroku

---

## 🔎 Jak to czytać?

- **Mózg = operacyjne minimum** (to, co potrzebne w nocy o 3:00, gdy telefon dzwoni).  
- **Repo = baza wiedzy** (wszystko inne, do sięgnięcia w kilka sekund).  

To jest normalne, że nie wiesz z głowy, ile dokładnie bajtów zajmuje `nvarchar(53)` w UTF-8.  
Ale musisz wiedzieć, **gdzie to sprawdzić** i jak to wpływa na Twoją bazę.

---

## 🧠 Mindset DBA

- DBA to nie „chodząca encyklopedia”, tylko **inżynier procesów**.  
- Twoim narzędziem jest **umiejętność zadawania pytań systemowi** (DMV, DBCC, XE).  
- Twoją bronią jest **repozytorium wiedzy**, które już tworzysz.  

---

_ostatnia aktualizacja: 2025-09-16_
