# ⚙️ SQL Server 2022 – Rekomendacje dla flag i ustawień instancji (Best Practices)

## 1) Serwer/instancja – szybkie włączenia
```sql
-- TempDB metadata in-memory (zmniejsza blokady przy katalogach temp)
ALTER SERVER CONFIGURATION SET MEMORY_OPTIMIZED TEMPDB_METADATA = ON;

-- Lightweight Query Profiling na poziomie baz (przez model dziedziczy się na nowe bazy)
ALTER DATABASE SCOPED CONFIGURATION SET LIGHTWEIGHT_QUERY_PROFILING = ON;

-- Query Store domyślnie włączony i w trybie RW w nowych bazach (przez model)
ALTER DATABASE [model] SET QUERY_STORE = ON (OPERATION_MODE = READ_WRITE);
```

## 2) TempDB – układ i wzrost
- Liczba plików: = liczbie rdzeni CPU, maksymalnie 8.
- Rozmiar startowy: ≥ 512 MB na plik; log tempdb ≥ 1024 MB.
- Auto-grow: stała wartość (np. 512 MB) – bez procentów.
- Dedykowany dysk T:\ i folder T:\MSSQL\TempDB.

## 3) MAXDOP (stopień równoległości)
Zalecenie: liczba rdzeni w **jednym** NUMA node (np. 8).
```sql
EXEC sys.sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sys.sp_configure 'max degree of parallelism', 8;  -- dopasuj do serwera
RECONFIGURE;
```

## 4) Cost Threshold for Parallelism
Domyślnie 5 (zbyt nisko). Startowo ustaw 50 i koryguj na podstawie obserwacji.
```sql
EXEC sys.sp_configure 'cost threshold for parallelism', 50; 
RECONFIGURE;
```

## 5) Pamięć (min/max)
- Min Server Memory: 1024 MB (bazowy start).
- Max Server Memory: RAM – (2–4 GB dla OS + inne serwisy).
```sql
EXEC sys.sp_configure 'min server memory (MB)', 1024; RECONFIGURE;
EXEC sys.sp_configure 'max server memory (MB)', 28672; RECONFIGURE; -- przykład dla 32 GB RAM
```

## 6) Instant File Initialization (IFI)
Włączone poprzez przywilej `SeManageVolumePrivilege` konta usługi.
```sql
SELECT servicename, instant_file_initialization_enabled
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server (%';
```

## 7) Trace flags (parametry startowe)
Dodaj w SQL Server Configuration Manager → Startup Parameters.
- `-T3226` – wycisza wpisy backupów w Error Log (czytelniejsze logi).
- `-T460` – dodatkowa diagnostyka Query Store (tymczasowo, gdy potrzebna).
> `-T1117/-T1118` – niepotrzebne od SQL Server 2016 (zachowanie domyślne).

## 8) Sieć
- Włącz TCP/IP, ustaw stały port (rozważ niestandardowy).
- Wyłącz Named Pipes i VIA (legacy).
- Jeśli używasz szyfrowania: włącz Force Encryption i zainstaluj certyfikat serwera.

## 9) Ustawienia bazy Model (dziedziczenie dla nowych baz)
```sql
ALTER DATABASE [model] MODIFY FILE (NAME = modeldev, SIZE = 128MB, FILEGROWTH = 128MB);
ALTER DATABASE [model] MODIFY FILE (NAME = modellog, SIZE = 64MB,  FILEGROWTH = 64MB);
```

## 10) Monitoring i alerty
- Extended Events: `system_health` (domyślnie), własne sesje na deadlocki i długe zapytania.
- Query Store: włączone, ustawienia rozmiaru i czyszczenia wg potrzeb.
- Database Mail + SQL Agent Alerts (Severity 16+ i konkretne zdarzenia).
- PBM (Policy-Based Management) do ciągłej zgodności konfiguracji.

## 11) Aktualizacje
- Po instalacji natychmiast wdrażaj najnowsze **Cumulative Updates (CU)**.
- Harmonogram przeglądu CU (np. raz w miesiącu) i testy w środowisku DEV przed PROD.
