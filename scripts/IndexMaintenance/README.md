# SQLManiak Index Maintenance

SQL Server 2022+. Centralna ewidencja i okresowy audyt indeksów, bez automatycznej przebudowy.

## Instalacja — kolejność

1. `001_CreateDatabase.sql` — tworzy bazę `SQLManiakIndexMaintenance` (nie zmienia istniejącej).
2. `002_CreateCoreSchema.sql` — `im.ManagedInstance`, `im.ManagedDatabase`, `im.AuditRun`.
3. `003_AuditModel.sql` — `im.IndexAssessment` (wynik osobno dla partycji).
4. `004_RunIndexAudit.sql` — procedura `im.RunIndexAudit`.
5. `005_AuditReports.sql` — raporty tylko do odczytu.

Skrypty są przewidziane dla instancji SQL Server 2022+; nie były jeszcze przetestowane na uruchomionej instancji w tym zadaniu. Przed użyciem produkcyjnym wykonaj test laboratoryjny oraz review praw i kosztu skanów. Wymagane są odpowiednie uprawnienia do DMV (w SQL Server 2022 co najmniej VIEW DATABASE STATE i VIEW DATABASE PERFORMANCE STATE na audytowanej bazie, zależnie od kontekstu i uprawnień administratora), a do instalacji — CREATE DATABASE oraz DDL w repozytorium.

## Przykład audytu

```sql
USE [SQLManiakIndexMaintenance];
GO
EXEC im.RunIndexAudit
 @DatabaseName = N'YourDatabase',
 @MinPagesForReview = 1000,
 @MinPagesForSample = 10000,
 @MaxSampledPartitions = 20;
GO
```

Parametry domyślne odpowiadają roboczym progom analizy. Audyt uruchamia się **na tej samej instancji**, na której znajduje się centralna baza. Obsługę wielu instancji rozbudujemy osobno. Dane identyfikują lokalną instancję i nazwę bazy; identyfikatory obiektów są zapisywane w kontekście przebiegu.

## Logika klasyfikacji — wersja wstępna

- `NO_ACTION` — fragmentacja poniżej 10%.
- `REORGANIZE_CANDIDATE` — fragmentacja 10–29,99%.
- `REBUILD_CANDIDATE` — fragmentacja co najmniej 30%, z wyłączeniem przypadków kierowanych do REVIEW.
- `REVIEW` — brak pomiaru, page density poniżej 70% (jeśli jest dostępna) lub bardzo duża partycja (co najmniej 100 000 stron) z fragmentacją co najmniej 30%.

To są **sygnały do weryfikacji**, nie decyzje o uruchomieniu ALTER INDEX. Fizyczna fragmentacja nie musi szkodzić wydajności (szczególnie w buforze); niska gęstość stron także wymaga oceny fill factor, wzorca zapisów, page splits i obciążenia. Dla danych wyłącznie LIMITED page density może być NULL. Limity skanów SAMPLED ograniczają koszty diagnostyki.

## Granice bieżącego etapu

- Badamy indeksy clustered i nonclustered rowstore na tabelach użytkownika, część IN_ROW_DATA, poziom liści.
- Pomijamy heaps, columnstore, XML, przestrzenne i inne typy indeksów; nie jest to jeszcze kompletny audyt wszystkich struktur.
- Nie wykonujemy REBUILD, REORGANIZE ani UPDATE STATISTICS.
- Nie wyłączamy backupów.
- Nie ma harmonogramu, kolejki wykonawczej ani automatyzacji PowerShell.
- Bezpieczne ponawianie skryptów CREATE/ALTER, z wyjątkiem ewentualnych zmian schematu wymagających migracji.

## Plan

Następne etapy: walidacja wyników i priorytetów na realnych bazach, metryki użycia i kosztu, kolejka, okna serwisowe, wykonawca PowerShell, obsługa wielu instancji, historia operacji.
