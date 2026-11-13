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

## Architektura otwarta — wiele klastrów i instancji

6. `006_ExtensibleTopology.sql` — model `im.Cluster`, `im.ClusterNode`, `im.ConnectionEndpoint`, `im.AuditPolicy` oraz opcjonalne powiązania instancji i baz. Migracja nie usuwa dotychczasowych danych.

**Zasady:** Każda instancja ma własny identyfikator, opcjonalny klaster, typ instalacji i zarządzany endpoint; klastry nie są zakodowane na stałe. Można dodawać nowe WSFC, FCI i instancje standalone bez zmiany struktury. Endpoint dla FCI wskazuje nazwę wirtualną, nie fizyczny węzeł. Nowo dodane instancje i endpointy domyślnie są wyłączone do czasu testu połączenia. Nie zapisujemy haseł w tabelach.

**Status realizacji:** Migracja zapewnia otwarty *model danych*. Obecny `im.RunIndexAudit` nadal działa wyłącznie na lokalnej instancji SQL z bazą repozytorium. Zdalny collector PowerShell, jego protokół przekazania wyników, uwierzytelnianie, blokady równoległych audytów oraz odporność na failover będą implementowane i testowane osobno. `MaxConcurrentHeavyAudits` jest obecnie parametrem konfiguracyjnym, jeszcze nie wymuszanym przez wykonawcę.

## Zdalny audyt — pilot (007–010)

Skrypty:
- `007_RemoteIngestion.sql`: staging, rozpoczęcie i zamknięcie audytu, lease per cluster (na dziś jedna ciężka analiza na klaster).
- `008_ClassifyRemote.sql`: klasyfikacja centralna na podstawie staging.
- `009_DiscoverAndRegister.sql`: rejestracja nowych celów przez konfigurację.
- `010_LeaseRecovery.sql`: porządkowanie wygasłych blokad i oznaczanie przerwanych przebiegów jako Failed.
- `collector/Collect-RemoteIndex.ps1`: odczyt DMV z docelowej bazy; wynik JSON.
- `collector/Invoke-CentralAudit.ps1`: kontroler przechodzący po włączonych celach, BulkCopy i klasyfikacja.
- `tests/Integration-Smoke.sql`, `tests/Test-Classifications.sql`: kontrola schematu, przebiegów i reguł.

### Procedura testu na dwóch instancjach

1. Zainstaluj SQL 001–010 w kolejności na centralnym serwerze (w środowisku TEST).
2. Zapewnij PowerShell 7.5 i bibliotekę `Microsoft.Data.SqlClient` w środowisku uruchomieniowym. Skrypty zakładają, że `Add-Type -AssemblyName Microsoft.Data.SqlClient` działa; zależność nie jest automatycznie instalowana. Wymagane są uprawnienia do odczytu DMV w docelowych bazach, wykonania procedur, odczytu konfiguracji i INSERT do im.RemoteIndexStage w repozytorium.
3. Rejestracja FCI (przykładowe nazwy):

```sql
USE SQLManiakIndexMaintenance;
EXEC im.RegisterTarget
 @InstanceName=N'SQLVNN01\\SQLINST01',
 @ServerAddress=N'SQLVNN01\\SQLINST01',
 @ClusterName=N'WSFC01',@InstanceType='FCI';
```

4. Zarejestruj kolejne cele analogicznie. Następnie jawnie włącz instancję, endpoint i wybrane bazy w `im.ManagedInstance`, `im.ConnectionEndpoint`, `im.ManagedDatabase` (wszystkie domyślnie wyłączone). Nową bazę dopisz przez INSERT z poprawnym `InstanceId` lub przygotowaną w następnym etapie procedurę onboardingu; nie zakładaj automatycznego skanowania wszystkich baz.
5. Uruchom z Windows PowerShell 7.5:

```powershell
pwsh -File ./collector/Invoke-CentralAudit.ps1 -RepositoryServer 'CENTRAL-SQL'
```

6. Zweryfikuj `tests/Integration-Smoke.sql` i raporty `005_AuditReports.sql`.

### Ograniczenia wersji pilotowej

- Brak automatycznego `ALTER INDEX`, `UPDATE STATISTICS`, zatrzymywania backupów i instalacji obiektów na zdalnych instancjach.
- Kontroler działa sekwencyjnie, więc kontrola współbieżności jest dodatkowo wymuszana przez centralny lease na klaster. Obecne `MaxConcurrentHeavyAudits` to parametr na przyszłość, nie aktywny limit większy niż 1.
- Restart po awarii nie wznawia niedokończonego odczytu od miejsca przerwania: po wygaśnięciu lease przebieg staje się Failed i nowy harmonogram może ponowić *cały* audyt. Zmiana właściciela FCI jest obsługiwana przez nazwę wirtualną w nowym połączeniu, lecz bieżąca sesja może się przerwać. Nie ma jeszcze automatycznej ponownej próby połączenia w obrębie tego samego przebiegu.
- Domyślny lease (240 minut kontrolera) wymaga dostosowania do najdłuższego audytu; w pilocie brak heartbeat/odnawiania dzierżawy. Nie uruchamiaj równoległych kontrolerów produkcyjnie bez odpowiedniego testu.
- Uwierzytelnianie Windows i TLS; `-TrustServerCertificate` wyłącznie w izolowanym laboratorium. Konfiguracja SQL i agent nie przechowują poświadczeń.
- SQL Server 2022+ (FCI, standalone); AG wymaga dodatkowego rozpoznania roli i uprawnień. Raport obejmuje tylko clustered/nonclustered rowstore, nie pełną inwentaryzację wszystkich indeksów.
- Tę wersję trzeba przetestować na rzeczywistych instancjach i obciążeniach. Testy SQL zawierają smoke-check i przykłady reguł, nie są jeszcze pełnymi automatycznymi testami integracyjnymi.
