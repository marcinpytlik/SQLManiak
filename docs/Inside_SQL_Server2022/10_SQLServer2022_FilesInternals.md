# 🗂️ SQL Server 2022 – Architektura plików bazy danych

---

## 📌 1. Pliki bazy danych

SQL Server używa **trzech typów plików**:

- **MDF** (Primary Data File)  
  - Główny plik bazy danych.  
  - Zawiera metadane, stronę rozruchową (Boot Page), systemowe obiekty.  
  - Musi istnieć w każdej bazie.  

- **NDF** (Secondary Data File)  
  - Dodatkowe pliki danych.  
  - Mogą być w osobnych **filegroupach** (np. dla archiwum, FG_HISTORY).  
  - Używane dla skalowania I/O, rozkładania danych.  

- **LDF** (Transaction Log File)  
  - Plik dziennika transakcyjnego.  
  - Rejestruje wszystkie zmiany przed zapisem do `.mdf/.ndf`.  
  - Niezbędny dla **ACID** (Atomicity, Consistency, Isolation, Durability).  

---

## 📌 2. Filegroupy

Filegroup = logiczna grupa plików danych.

- **PRIMARY** – zawiera plik MDF, systemowe obiekty (system tables, katalogi).  
- **Użytkownika** (np. FG_DATA, FG_ARCHIVE) – do przenoszenia tabel/indeksów.  
- **FILESTREAM** – przechowywanie danych binarnych w systemie plików.  
- **MEMORY_OPTIMIZED_DATA** – dla tabel In-Memory OLTP.  

👉 Po co filegroupy?
- Skalowanie I/O (różne dyski).  
- Backup/restore per filegroup.  
- Archiwizacja (np. readonly filegroup).  
- Oddzielenie tempowych danych (FG_TEMP).  

---

## 📌 3. Budowa pliku danych (.MDF/.NDF)

### Jednostki:
- **Strona (Page)** = 8 KB  
- **Extent** = 8 stron (64 KB)  
- **GAM Interval** = 64,000 extents (4 GB)  

### Specjalne strony w każdym pliku:
- **File Header Page** (page_id = 0) → metadane pliku (rozmiar, ID, ścieżka).  
- **PFS (Page Free Space)** → co 8,088 stron (~64 MB).  
- **GAM (Global Allocation Map)** → co 64,000 stron (~4 GB).  
- **SGAM (Shared Global Allocation Map)** → co 64,000 stron (~4 GB).  
- **DCM (Differential Changed Map)** → co 511,232 stron (~4 GB).  
- **BCM (Bulk Change Map)** → co 511,232 stron (~4 GB, backup log).  

### Boot Page:
- Zawsze w **file_id=1, page_id=9**.  
- Informacje o bazie: ID, nazwa, rozmiar, compatibility level.  

---

## 📌 4. Budowa pliku logu (.LDF)

Plik logu jest **ciągłym zapisem sekwencyjnym** (append-only).

### Struktura logiczna:
- **VLF (Virtual Log File)**  
  - Log podzielony na segmenty VLF (kilkadziesiąt MB – rozmiar zależy od algorytmu).  
  - Każdy VLF ma stan: aktywny, nieaktywny, oczekujący na odzyskanie.  
  - Zbyt wiele małych VLF → problem z wydajnością (fragmentacja logu).  

### Struktura wewnętrzna:
- Każdy zapis = **log record** (LOP_INSERT_ROWS, LOP_DELETE_ROWS, LOP_BEGIN_XACT, LOP_COMMIT_XACT).  
- Każdy rekord wskazuje poprzedni (`PrevLSN`) → łańcuch transakcji.  
- Kluczowe pola: LSN (Log Sequence Number), Transaction ID, Page ID.  

### Cykl:
1. Transakcja zaczyna → log record `LOP_BEGIN_XACT`.  
2. Zmiany → log records (Insert/Update/Delete).  
3. Commit → `LOP_COMMIT_XACT`.  
4. Checkpoint/backup log → zwalnia nieaktywne VLF.  

---

## 📌 5. Jak to podejrzeć w SQL Server

```sql
-- Pliki i filegroupy
SELECT name, type_desc, physical_name, size*8/1024 AS size_MB, state_desc
FROM sys.master_files
WHERE database_id = DB_ID('AdventureWorks2022');

-- Filegroups
SELECT fg.name, fg.type_desc, f.name AS file_name, f.physical_name
FROM sys.filegroups fg
JOIN sys.database_files f ON fg.data_space_id = f.data_space_id;

-- Virtual Log Files
DBCC LOGINFO;       -- stary
DBCC LOGINFO('AdventureWorks2022');  -- nowszy (2016+)
DBCC LOGINFO(2);    -- dla database_id=2

-- Alternatywa (2017+)
SELECT * FROM sys.dm_db_log_info(DB_ID('AdventureWorks2022'));
```

---

## 🔎 Podsumowanie

- Każda baza = minimum **1×MDF + 1×LDF**.  
- Filegroupy pozwalają na elastyczne zarządzanie przestrzenią i backupami.  
- Strony kontrolne (PFS, GAM, SGAM, DCM, BCM) są cyklicznie powtarzane w plikach.  
- Log transakcyjny działa sekwencyjnie, z podziałem na **VLF**.  
- DBA musi znać relacje: **Page → Extent → File → Filegroup → Database**.  

---

_ostatnia aktualizacja: 2025-09-16_
