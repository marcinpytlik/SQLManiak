# LogLab & tempdb — demo rozrostu i odchudzania LOG-a (SQL Server 2022)

Repo-ready paczka laboratoriów pokazujących:
- jak napompować **transaction log**,
- co realnie skraca log (truncation vs. shrink),
- dlaczego `DBCC SHRINKFILE` często “nic nie robi”,
- różnice **FULL vs SIMPLE**,
- wpływ VLF-ów i autogrowth,
- diagnostykę `log_truncation_holdup_reason`,
- oraz **tempdb** z *version store* (snapshot/online index/wersjonowanie).

## Wymagania
- SQL Server 2022 (Developer/Enterprise) – lokalnie lub zdalnie.
- VS Code (opcjonalnie: rozszerzenie *SQL Server (mssql)*).
- Uprawnienia do zapisu na `C:\Temp\` (domyślne ścieżki backupów w skryptach).

> Wszystkie skrypty są idempotentne i bezpieczne w labie. **Nie** uruchamiaj ich w produkcji.

## Struktura
```
LogLab_Tempdb_LogDemo/
├─ .vscode/
│  └─ tasks.json                # Przykładowe taski do uruchamiania labów z VS Code (sqlcmd)
├─ Lab00_Setup.sql
├─ Lab01_GrowLog.sql
├─ Lab02_ShrinkWithoutTruncation.sql
├─ Lab03_ActiveTransactionBlocksTruncation.sql
├─ Lab04_SimpleVsFull.sql
├─ Lab05_VLFs_and_Autogrowth.sql
├─ Lab06_Diagnostics.sql
├─ Lab07_tempdb_VersionStore.sql
└─ README.md
```

## Szybki start
1. Otwórz folder w VS Code.
2. W `Lab00_Setup.sql` ustaw ścieżki backupów pod swój serwer (domyślnie `C:\Temp\`), uruchom plik.
3. Odpalaj kolejne laby **po kolei**. Dla Lab03 użyj *dwóch sesji* (A/B), jak opisano w treści skryptu.

## Weryfikacja (checkpoints)
- Używaj:
  ```sql
  SELECT * FROM sys.dm_db_log_stats(DB_ID());
  DBCC SQLPERF(LOGSPACE);
  SELECT * FROM sys.dm_db_log_info(DB_ID());
  ```
- W tempdb:
  ```sql
  SELECT (version_store_reserved_page_count/128.0) AS MB_version_store
  FROM sys.dm_db_file_space_usage;
  ```

## Notatki operacyjne
- W **FULL** zadziała dopiero: *BACKUP LOG* → *DBCC SHRINKFILE*.
- W **SIMPLE** truncation wykonuje *CHECKPOINT*.
- Hamulce: `ACTIVE_TRANSACTION`, `REPLICATION`, `AVAILABILITY_REPLICA`, `LOG_BACKUP`, `XTP_CHECKPOINT`, `OTHER`.
- `tempdb` kurczy się dopiero, gdy **zwolni się version store** (zakończ transakcje snapshot/online index), potem `CHECKPOINT` i dopiero `DBCC SHRINKFILE`.

## Ustawienia docelowe (po “diecie”)
Po demonstracji przywróć sensowny rozmiar i wzrost pliku LOG:
```sql
ALTER DATABASE LogLab MODIFY FILE (NAME = LogLab_log, SIZE = 8192MB, FILEGROWTH = 512MB);
```
