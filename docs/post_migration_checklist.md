> **Content status:** REFERENCE  
> **Canonical entry point:** [DBA Library](../runbooks/sql2016-to-2022-migration/)  
> **Last reviewed:** 2026-09-30  
> Checklistę zachowujemy jako referencję; canonical procedure to migration runbook.

📄 SQL Server – Post-Migration Checklist (2016 → 2022)


✅ 1. Stan bazy i metadanych

✅ 2. Statystyki i indeksy

✅ 3. Bezpieczeństwo i uprawnienia

✅ 4. Konfiguracja instancji

✅ 5. Agent i zadania

✅ 6. SSIS / Integration Services

✅ 7. Monitorowanie i wydajność

✅ 8. Backupy i odzyskiwanie

📌 Dodatkowe kroki

📜 Licencja

Migracja bazy danych do nowej wersji SQL Server nie kończy się na samym odtworzeniu kopii zapasowej.
Poniższa checklista pomaga upewnić się, że baza i instancja są w pełni przygotowane do pracy produkcyjnej.

✅ 1. Stan bazy i metadanych

Uruchom DBCC CHECKDB na wszystkich bazach po migracji.

Sprawdź compatibility level:

ALTER DATABASE [TwojaBaza] SET COMPATIBILITY_LEVEL = 160;

✅ 2. Statystyki i indeksy

Przebuduj indeksy:

ALTER INDEX ALL ON [TwojaTabela] REBUILD;


Zaktualizuj statystyki z pełnym skanem:

UPDATE STATISTICS [TwojaTabela] WITH FULLSCAN;

✅ 3. Bezpieczeństwo i uprawnienia

Zweryfikuj loginy i mapowania użytkowników:

ALTER USER [user] WITH LOGIN = [login];


Sprawdź polityki haseł i zasady bezpieczeństwa.

✅ 4. Konfiguracja instancji

Przenieś ustawienia serwera (sp_configure), m.in.:

maxdop

cost threshold for parallelism

max server memory

Zweryfikuj trace flagi – część z SQL 2016 jest w SQL 2022 domyślnie włączona.

Skonfiguruj tempdb (liczba i wielkość plików, autogrowth).

✅ 5. Agent i zadania

Zweryfikuj zadania SQL Server Agent (backupy, maintenances, SSIS).

Sprawdź harmonogramy i operatorów – skonfiguruj Database Mail jeśli potrzeba.

✅ 6. SSIS / Integration Services

Jeśli używasz SSISDB, wykonaj upgrade paczek do wersji 2022 (Deployment Wizard / re-deploy).

✅ 7. Monitorowanie i wydajność

Włącz i skonfiguruj Query Store (w 2022 jest domyślnie aktywny).

Sprawdź wait stats i nowe DMV (sys.dm_db_log_stats, sys.dm_db_page_info).

Przetestuj krytyczne zapytania pod kątem regresji planów.

✅ 8. Backupy i odzyskiwanie

Zweryfikuj strategię backupów (FULL, DIFF, LOG).

Przetestuj przywracanie bazy w SQL Server 2022, aby upewnić się, że łańcuch backupów działa.

📌 Dodatkowe kroki

Dokumentacja wszystkich zmian w konfiguracji.

Komunikacja z zespołem dev/QA – testy aplikacyjne.

Monitoring po migracji (alerty, baseline performance).

📜 Licencja

Repozytorium sqlmaniak
Licencja: CC BY 4.0

Autor: Marcin (SQLManiak)