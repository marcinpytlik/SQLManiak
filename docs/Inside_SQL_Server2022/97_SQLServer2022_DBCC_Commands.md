# 🗂️ SQL Server DBCC Commands – Spis

## ✅ Oficjalnie wspierane polecenia DBCC

- **DBCC CHECKDB** – sprawdza integralność całej bazy (opcje: NOINDEX, REPAIR_ALLOW_DATA_LOSS itd.).
- **DBCC CHECKALLOC** – sprawdza poprawność struktur alokacji (extentów, PFS, GAM).
- **DBCC CHECKTABLE** – sprawdza spójność pojedynczej tabeli.
- **DBCC CHECKFILEGROUP** – sprawdza spójność danych w wybranej filegroup.
- **DBCC CHECKCATALOG** – weryfikuje integralność metadanych (sys.objects, sys.columns itd.).
- **DBCC SHRINKDATABASE** – zmniejsza rozmiar bazy.
- **DBCC SHRINKFILE** – zmniejsza rozmiar pliku MDF/LDF.
- **DBCC SQLPERF(LOGSPACE)** – raportuje zajętość logów transakcyjnych.
- **DBCC DBREINDEX** *(deprecated)* – przebudowa indeksów (zastąpione `ALTER INDEX`).
- **DBCC SHOWCONTIG** *(deprecated)* – raport fragmentacji (zastąpione DMV).
- **DBCC FREEPROCCACHE** – czyści cache planów zapytań.
- **DBCC FREESYSTEMCACHE** – czyści cache metadanych i planów (per resource pool).
- **DBCC FREESESSIONCACHE** – czyści cache sesji logowania.
- **DBCC DROPCLEANBUFFERS** – czyści buffer pool (symulacja „cold cache”).
- **DBCC TRACEON / TRACEOFF** – włączanie/wyłączanie trace flagów.
- **DBCC TRACESTATUS** – status trace flagów.
- **DBCC INPUTBUFFER (SPID)** – pokazuje ostatnie polecenie sesji.
- **DBCC OPENTRAN** – pokazuje najstarszą otwartą transakcję.
- **DBCC OUTPUTBUFFER (SPID)** – bufor wyjściowy danej sesji.
- **DBCC PROCCACHE** – informacje o procedurach w cache.
- **DBCC SHOW_STATISTICS (tabela, indeks)** – pokazuje histogram statystyk.
- **DBCC UPDATEUSAGE** – aktualizuje metadane row/page count w sysindexes.
- **DBCC CHECKIDENT** – sprawdza i ustawia wartość IDENTITY w tabeli.
- **DBCC DBINFO** *(nieudokumentowane, ale powszechnie używane)* – szczegóły bazy (m.in. MinLSN).

---

## 🔍 Niedokumentowane / diagnostyczne

- **DBCC PAGE (dbid, file, page, printopt)** – podgląd surowej strony w MDF/NDF.
- **DBCC IND (dbid, object, index)** – listuje wszystkie strony należące do obiektu.
- **DBCC CHECKPRIMARYFILE** – sprawdza nagłówek pliku danych.
- **DBCC LOG (dbid, type)** – podgląd wpisów w logu transakcyjnym.
- **DBCC LOGINFO** *(<= 2016)* – pokazuje strukturę VLF w logu (zastąpione DMV).
- **DBCC CLONEDATABASE** – klonuje bazę (struktury + statystyki, bez danych).
- **DBCC WRITEPAGE** *(niebezpieczne!)* – zapisuje surowe dane na stronę.
- **DBCC WRITELOG** *(wewnętrzne, eksperymentalne)* – wpis do loga.
- **DBCC BYTES** – ukryte narzędzie diagnostyczne używane przez MS.
- **DBCC HELP (‘?’)** – lista poleceń DBCC w danej wersji SQL.
- **DBCC PERFMON** *(stare)* – liczby o wydajności.
- **DBCC MEMORYSTATUS** – raport o użyciu pamięci (clerks, caches).
- **DBCC STACKDUMP** – dump stosu dla SPID.
- **DBCC THREADS** – info o workerach i schedulerach.
- **DBCC PERFMON / SQLPERF** – raporty wydajnościowe.
- **DBCC SHOWCONTIG** *(stare, zamienione DMV)* – fragmentacja indeksów.
- **DBCC CHECKDB WITH TABLOCK** – tryb szybki, blokujący.

---

## 📌 Wskazówka

Pełną listę dostępnych poleceń DBCC w danej wersji SQL Server:

```sql
DBCC HELP ('?');
```

A szczegóły konkretnego polecenia:

```sql
DBCC HELP ('CHECKDB');
```
