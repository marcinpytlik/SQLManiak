# SqlStressLab

SqlStressLab to lekkie narzędzie CLI w C# do generowania równoległego obciążenia SQL Server, analizy wyników oraz porównywania i śledzenia trendów kolejnych uruchomień.

## Funkcje

### Core workload
- wielu workerów
- wiele iteracji
- mixed authentication
- ustawienia sesji `SET` z pliku `.sql`
- `Text` / `StoredProcedure`
- `NonQuery` / `Scalar` / `Reader`
- retry dla wybranych błędów SQL
- warmup przed właściwym runem
- worker assignments dla scenariuszy specjalnych

### Raportowanie
- raport JSON
- raport CSV
- reader preview
- raport Markdown
- raport HTML

### Diagnostyka i analiza
- snapshoty DMV before / after
- zapis wyników do SQL Server
- porównanie bieżącego runu do baseline
- analiza trendu ostatnich N runów

### Scenariusze
- `General`
- `BlockingHotRow`
- `DeadlockPair`
- `ReadStorm`
- `WriteStorm`

---

## Uruchomienie

```powershell
$env:SQLSTRESSLAB_PASSWORD="BardzoMocneHaslo!123"
dotnet run --project .\src\SqlStressLab.Cli\SqlStressLab.Cli.csproj -- .\src\SqlStressLab.Cli\profiles\demo-select.json
```

Po publish:

```powershell
.\SqlStressLab.Cli.exe .\profiles\demo-select.json
```

---

# SqlStressLab — spis klas na finał Sprintu 6

Ten dokument opisuje klasy obecne w projekcie `SqlStressLab` na koniec Sprintu 6 oraz ich rolę w rozwiązaniu.

## Struktura rozwiązania

Projekt składa się z dwóch głównych części:

- `SqlStressLab.Cli` — aplikacja konsolowa uruchamiająca workload i spinająca cały przepływ
- `SqlStressLab.Core` — biblioteka z modelami, usługami, scenariuszami, raportowaniem, compare/trend i integracją z SQL Server

---

# 1. Warstwa CLI

## Program
**Plik:** `src/SqlStressLab.Cli/Program.cs`

Główny punkt wejścia aplikacji konsolowej.

### Odpowiedzialność
- wczytanie pliku profilu JSON
- rozwiązanie ścieżek względnych
- pobranie hasła z `SQLSTRESSLAB_PASSWORD`
- zbudowanie `StressOptions`
- uruchomienie setup/cleanup
- zbudowanie planu scenariusza
- uruchomienie `StressRunner`
- zebranie snapshotów DMV
- wygenerowanie raportów JSON/CSV/Markdown/HTML
- zapis wyników do SQL Server
- wykonanie compare do baseline
- wykonanie analizy trendu

---

# 2. Modele domenowe (`Models`)

## CliArguments
**Plik:** `Models/CliArguments.cs`

Model argumentów CLI.

### Odpowiedzialność
- przechowuje komendę CLI
- przechowuje ścieżkę do profilu
- obsługuje dane do compare/trend, np.:
  - `CurrentRunId`
  - `BaselineRunId`
  - `ProfileName`
  - `Top`

---

## CompareOptions
**Plik:** `Models/CompareOptions.cs`

Konfiguracja compare.

### Odpowiedzialność
- włączenie/wyłączenie compare
- tryb compare:
  - `None`
  - `PreviousRun`
  - `ExplicitRunId`
- opcjonalny `BaselineRunId`
- flaga `IncludeSampleLevelDiff`

---

## TrendOptions
**Plik:** `Models/TrendOptions.cs`

Konfiguracja analizy trendu.

### Odpowiedzialność
- włączenie/wyłączenie trend analysis
- liczba ostatnich runów (`Top`) do analizy

---

## TrendPoint
**Plik:** `Models/TrendPoint.cs`

Pojedynczy punkt trendu.

### Odpowiedzialność
- `RunId`
- `StartedAtUtc`
- `AvgDurationMs`
- `P95DurationMs`
- `ThroughputPerSecond`
- `ErrorCount`

---

## TrendAnalysisResult
**Plik:** `Models/TrendAnalysisResult.cs`

Wynik analizy trendu.

### Odpowiedzialność
- przechowuje listę punktów trendu
- przechowuje kierunek zmian:
  - `AvgDurationTrendDirection`
  - `P95DurationTrendDirection`
  - `ThroughputTrendDirection`
  - `ErrorTrendDirection`
- przechowuje końcowy `SummaryVerdict`

---

## RunComparisonResult
**Plik:** `Models/RunComparisonResult.cs`

Wynik porównania bieżącego runu do baseline.

### Odpowiedzialność
- `RunId`
- `BaselineRunId`
- delta AVG
- delta P95
- delta throughput
- delta error count
- delta retry count
- `IsRegression`
- `SummaryText`

---

## StressRunComparisonRecord
**Plik:** `Models/StressRunComparisonRecord.cs`

Model przygotowany do zapisu compare do SQL Server.

### Odpowiedzialność
- zapisuje najważniejsze różnice między current a baseline
- trafia do tabeli `dbo.StressRunComparison`

---

## DmvSnapshot
**Plik:** `Models/DmvSnapshot.cs`

Reprezentuje pojedynczy zestaw snapshotów DMV dla jednej fazy (`Before` / `After`) i jednego typu snapshotu.

### Odpowiedzialność
- przechowuje metadane snapshotu
- przechowuje listę wierszy `DmvSnapshotRow`

---

## DmvSnapshotRow
**Plik:** `Models/DmvSnapshotRow.cs`

Reprezentuje pojedynczy wiersz snapshotu DMV zapisany jako JSON.

### Odpowiedzialność
- przechowuje dane jednego rekordu DMV
- służy do zapisu do tabeli `StressRunDmvSnapshot`

---

## EnvironmentInfo
**Plik:** `Models/EnvironmentInfo.cs`

Model środowiska uruchomieniowego klienta.

### Odpowiedzialność
- nazwa środowiska
- nazwa maszyny
- wersja systemu
- wersja .NET

---

## ExecutionConfig
**Plik:** `Models/ExecutionConfig.cs`

Sekcja konfiguracji wykonania odczytywana z profilu JSON.

### Odpowiedzialność
- opisuje jak uruchomić workload:
  - `commandText`
  - `commandType`
  - `executionMode`
  - `workers`
  - `iterationsPerWorker`
  - timeout
  - warmup
  - session settings
  - opóźnienia

---

## ExecutionSample
**Plik:** `Models/ExecutionSample.cs`

Model pojedynczej próby wykonania zapytania lub procedury.

### Odpowiedzialność
- przechowuje wynik jednego wykonania
- czas trwania
- sukces/błąd
- numer błędu SQL
- retry attempt
- scalar value / reader row count
- dane kontekstu sesji:
  - `Spid`
  - `HostName`
  - `AppName`
  - `LoginName`
  - `DatabaseName`

---

## HtmlReportOptions
**Plik:** `Models/HtmlReportOptions.cs`

Opcje generowania raportu HTML.

### Odpowiedzialność
- steruje generowaniem sekcji HTML
- określa katalog docelowy i zakres raportu
- kontroluje sekcje:
  - DMV
  - slow samples
  - comparison
  - trend

---

## MarkdownReportOptions
**Plik:** `Models/MarkdownReportOptions.cs`

Opcje generowania raportu Markdown.

### Odpowiedzialność
- steruje generowaniem raportu `.md`
- określa liczbę najwolniejszych próbek i sekcje błędów
- wspiera sekcje compare/trend

---

## OutputOptions
**Plik:** `Models/OutputOptions.cs`

Opcje zapisu artefaktów plikowych.

### Odpowiedzialność
- włączenie zapisu JSON
- włączenie zapisu CSV
- włączenie zapisu reader preview
- katalog wyjściowy

---

## ProgressSnapshot
**Plik:** `Models/ProgressSnapshot.cs`

Model postępu runu raportowanego do konsoli.

### Odpowiedzialność
- liczba wszystkich planowanych wykonań
- liczba zakończonych wykonań
- sukcesy
- błędy
- retry

---

## ProgressTracker
**Plik:** `Models/ProgressTracker.cs`

Model pomocniczy do śledzenia postępu wykonania.

### Odpowiedzialność
- przechowuje bieżący stan postępu runu
- może być wykorzystywany przez runner lub warstwę raportowania

---

## RetryOptions
**Plik:** `Models/RetryOptions.cs`

Konfiguracja retry dla workloadu.

### Odpowiedzialność
- włączenie/wyłączenie retry
- liczba retry
- opóźnienie między próbami
- lista retryable SQL error numbers

---

## RetryPolicy
**Plik:** `Models/RetryPolicy.cs`

Model/pomocnik opisujący logikę retry.

### Odpowiedzialność
- formalizuje zasady retry
- wspiera podejście retry w runnerze

---

## RootConfig
**Plik:** `Models/RootConfig.cs`

Główny model konfiguracji odczytywany z pliku JSON.

### Odpowiedzialność
- scala wszystkie sekcje konfiguracyjne:
  - połączenie
  - execution
  - retry
  - output
  - sqlOutput
  - lifecycle
  - environment
  - markdown/html report
  - tags
  - parameters
  - compare
  - trend

---

## RunArtifactInfo
**Plik:** `Models/RunArtifactInfo.cs`

Model opisujący artefakty wygenerowane dla runu.

### Odpowiedzialność
- ścieżki do plików raportów
- ścieżki do plików wynikowych

---

## RunLifecycleOptions
**Plik:** `Models/RunLifecycleOptions.cs`

Opcje lifecycle runu.

### Odpowiedzialność
- włączenie setup
- włączenie cleanup
- ścieżki do skryptów SQL
- zachowanie w przypadku błędu setup/cleanup

---

## ScenarioDefinition
**Plik:** `Models/ScenarioDefinition.cs`

Definicja scenariusza workloadu.

### Odpowiedzialność
- nazwa scenariusza
- opis
- typ scenariusza
- domyślne pliki setup/cleanup
- wymagania dotyczące DMV
- wymagania dotyczące pairing workerów

---

## ScenarioExecutionPlan
**Plik:** `Models/ScenarioExecutionPlan.cs`

Plan wykonania scenariusza.

### Odpowiedzialność
- finalna definicja scenariusza
- worker assignments
- efektywne pliki setup/cleanup

---

## SessionInfo
**Plik:** `Models/SessionInfo.cs`

Model kontekstu sesji SQL Server.

### Odpowiedzialność
- `SPID`
- `host_name`
- `program_name`
- `login_name`
- `database_name`

---

## SqlAuthOptions
**Plik:** `Models/SqlAuthOptions.cs`

Model konfiguracji połączenia do SQL Server.

### Odpowiedzialność
- serwer
- baza
- tryb uwierzytelnienia
- login/hasło
- encrypt / trust server certificate
- application name

---

## SqlOutputOptions
**Plik:** `Models/SqlOutputOptions.cs`

Konfiguracja zapisu wyników do SQL Server.

### Odpowiedzialność
- włączenie/wyłączenie SQL output
- tryb połączenia:
  - `SameAsTarget`
  - `Separate`
- opcjonalne osobne połączenie do repozytorium wyników

---

## SqlParameterDefinition
**Plik:** `Models/SqlParameterDefinition.cs`

Definicja pojedynczego parametru wejściowego dla komendy SQL.

### Odpowiedzialność
- nazwa parametru
- typ SQL
- tryb generowania wartości:
  - `Fixed`
  - `WorkerId`
  - `Iteration`
  - `RandomIntRange`
  - `Sequence`
- pola pomocnicze:
  - `Value`
  - `Min`
  - `Max`
  - `Start`
  - `Increment`

---

## SqlServerEnvironmentInfo
**Plik:** `Models/SqlServerEnvironmentInfo.cs`

Model metadanych środowiska SQL Server.

### Odpowiedzialność
- `ProductVersion`
- `ProductLevel`
- `Edition`
- `EngineEdition`
- `InstanceName`
- `CompatibilityLevel`

---

## StressOptions
**Plik:** `Models/StressOptions.cs`

Finalny model opcji wykonania przekazywany do `StressRunner`.

### Odpowiedzialność
- gotowe ustawienia workloadu po odczycie i przetworzeniu konfiguracji
- parametry potrzebne do wykonania runu

---

## StressRunRecord
**Plik:** `Models/StressRunRecord.cs`

Reprezentuje nagłówek runu zapisywany do tabeli `dbo.StressRun`.

### Odpowiedzialność
- dane identyfikujące run
- statystyki wykonania
- metadane środowiska klienta
- metadane środowiska SQL Server
- tagi i nazwy profilu/scenariusza

---

## StressRunResult
**Plik:** `Models/StressRunResult.cs`

Model wyniku zwracanego przez `StressRunner`.

### Odpowiedzialność
- `RunId`
- `StartedAtUtc`
- `FinishedAtUtc`
- `RetryCount`
- `Summary`
- lista `Samples`

---

## StressRunSampleRecord
**Plik:** `Models/StressRunSampleRecord.cs`

Model pojedynczej próbki przygotowany do zapisu do SQL Server.

### Odpowiedzialność
- odwzorowanie `ExecutionSample` na rekord tabeli `dbo.StressRunSample`

---

## StressSummary
**Plik:** `Models/StressSummary.cs`

Model zagregowanego podsumowania runu.

### Odpowiedzialność
- `TotalExecutions`
- `SuccessCount`
- `ErrorCount`
- `AvgDurationMs`
- `MinDurationMs`
- `P50DurationMs`
- `P95DurationMs`
- `P99DurationMs`
- `MaxDurationMs`
- `ThroughputPerSecond`

---

## TagOptions
**Plik:** `Models/TagOptions.cs`

Model tagów konfiguracyjnych.

### Odpowiedzialność
- lista tagów przypisanych do runu

---

## WorkerAssignment
**Plik:** `Models/WorkerAssignment.cs`

Przypisanie roli i ewentualnych override dla konkretnego workera.

### Odpowiedzialność
- `WorkerId`
- `Role`
- override `CommandText`
- override `CommandType`

---

## WorkerContext
**Plik:** `Models/WorkerContext.cs`

Model pomocniczy opisujący kontekst pojedynczego workera.

### Odpowiedzialność
- przechowuje dane potrzebne podczas wykonania per worker
- wspiera scenariusze różnicujące role workerów

---

# 3. Usługi (`Services`)

## RunCommandService
**Plik:** `Services/RunCommandService.cs`

Serwis obsługujący komendę `run`.

### Odpowiedzialność
- uruchamianie runu na podstawie argumentów CLI
- delegowanie do głównego przepływu wykonania

---

## CompareCommandService
**Plik:** `Services/CompareCommandService.cs`

Serwis obsługujący komendę `compare`.

### Odpowiedzialność
- uruchamianie porównania current vs baseline
- budowa wyniku compare

---

## TrendCommandService
**Plik:** `Services/TrendCommandService.cs`

Serwis obsługujący komendę `trend`.

### Odpowiedzialność
- analiza trendu dla ostatnich N runów
- budowa wyniku trend analysis

---

## RunComparisonService
**Plik:** `Services/RunComparisonService.cs`

Serwis compare.

### Odpowiedzialność
- porównuje `StressRunRecord` current i baseline
- wylicza delty:
  - AVG
  - P95
  - throughput
  - error count
  - retry count
- wyznacza `IsRegression`

---

## TrendAnalysisService
**Plik:** `Services/TrendAnalysisService.cs`

Serwis analizy trendu.

### Odpowiedzialność
- analizuje listę ostatnich runów
- buduje `TrendPoint`
- wyznacza kierunki zmian
- zwraca `TrendAnalysisResult`

---

## BuiltInScenarioCatalog
**Plik:** `Services/BuiltInScenarioCatalog.cs`

Katalog wbudowanych scenariuszy.

### Odpowiedzialność
- zwraca definicję scenariusza po nazwie
- przechowuje wbudowane scenariusze, np.:
  - `General`
  - `BlockingHotRow`
  - `DeadlockPair`
  - `ReadStorm`
  - `WriteStorm`

---

## BulkSampleWriter
**Plik:** `Services/BulkSampleWriter.cs`

Zapisuje próbki do SQL Server przez `SqlBulkCopy`.

### Odpowiedzialność
- szybki zapis `StressRunSampleRecord`
- wydajniejsza alternatywa dla pojedynczych insertów

---

## ConnectionStringFactory
**Plik:** `Services/ConnectionStringFactory.cs`

Buduje connection string do SQL Server.

### Odpowiedzialność
- tworzy connection string na podstawie `SqlAuthOptions`
- wspiera mixed auth i integrated security

---

## DmvSnapshotCollector
**Plik:** `Services/DmvSnapshotCollector.cs`

Zbiera snapshoty DMV.

### Odpowiedzialność
- pobiera dane z DMV before/after run
- zwraca listę `DmvSnapshot`
- wspiera analizę scenariuszy blocking/deadlock/waits

---

## EnvironmentCollector
**Plik:** `Services/EnvironmentCollector.cs`

Zbiera podstawowe informacje o środowisku klienta.

### Odpowiedzialność
- nazwa środowiska
- nazwa hosta
- wersja systemu
- wersja .NET

---

## HtmlReportWriter
**Plik:** `Services/HtmlReportWriter.cs`

Generuje raport HTML dla runu.

### Odpowiedzialność
- tworzy raport wizualny runu
- może zawierać:
  - summary
  - błędy
  - próbki
  - sekcję środowiska SQL
  - sekcję DMV
  - sekcję compare
  - sekcję trend

---

## LifecycleScriptRunner
**Plik:** `Services/LifecycleScriptRunner.cs`

Uruchamia pliki SQL dla setup/cleanup.

### Odpowiedzialność
- wykonanie skryptu setup
- wykonanie skryptu cleanup
- obsługa timeoutu

---

## MarkdownReportWriter
**Plik:** `Services/MarkdownReportWriter.cs`

Generuje raport Markdown.

### Odpowiedzialność
- tworzy raport `.md`
- przydatny do Obsidiana, dokumentacji i historii runów
- wspiera sekcje compare/trend

---

## MetricsCalculator
**Plik:** `Services/MetricsCalculator.cs`

Warstwa licząca metryki z listy próbek.

### Odpowiedzialność
- percentyle
- średnie
- min/max
- throughput
- wspiera budowę `StressSummary`

---

## ParameterValueFactory
**Plik:** `Services/ParameterValueFactory.cs`

Tworzy wartości parametrów SQL na podstawie definicji parametru.

### Odpowiedzialność
- generuje wartość dla:
  - `Fixed`
  - `WorkerId`
  - `Iteration`
  - `RandomIntRange`
  - `Sequence`
- konwertuje wartości na typy SQL/.NET

---

## ReportWriter
**Plik:** `Services/ReportWriter.cs`

Generuje podstawowe artefakty plikowe runu.

### Odpowiedzialność
- zapis JSON
- zapis CSV
- zapis reader preview

---

## ScenarioPlanner
**Plik:** `Services/ScenarioPlanner.cs`

Buduje plan wykonania scenariusza.

### Odpowiedzialność
- pobiera definicję scenariusza
- dobiera setup/cleanup
- buduje `WorkerAssignments`
- zwraca `ScenarioExecutionPlan`

---

## SessionContextLoader
**Plik:** `Services/SessionContextLoader.cs`

Pobiera informacje o aktualnej sesji SQL Server.

### Odpowiedzialność
- ładuje `SessionInfo`
- zbiera:
  - `SPID`
  - `host_name`
  - `program_name`
  - `login_name`
  - `database_name`

---

## SessionSettingsLoader
**Plik:** `Services/SessionSettingsLoader.cs`

Ładuje plik z ustawieniami sesji SQL.

### Odpowiedzialność
- odczyt `session-settings.sql`
- przygotowanie zawartości do wykonania

---

## SqlExecutor
**Plik:** `Services/SqlExecutor.cs`

Warstwa wykonująca pojedynczą komendę SQL.

### Odpowiedzialność
- wykonanie `Text` lub `StoredProcedure`
- obsługa:
  - `NonQuery`
  - `Scalar`
  - `Reader`
- współpraca z parametrami i sesją

---

## SqlResultRepository
**Plik:** `Services/SqlResultRepository.cs`

Repozytorium zapisu i odczytu wyników runów w SQL Server.

### Odpowiedzialność
- zapis `StressRun`
- zapis `StressRunSample`
- zapis snapshotów DMV
- zapis compare
- odczyt runu po `RunId`
- pobranie ostatnich runów po profilu

---

## SqlServerEnvironmentCollector
**Plik:** `Services/SqlServerEnvironmentCollector.cs`

Zbiera metadane środowiska SQL Server.

### Odpowiedzialność
- wersja produktu
- poziom produktu
- edycja
- engine edition
- nazwa instancji
- compatibility level

---

## StressRunner
**Plik:** `Services/StressRunner.cs`

Główny silnik workloadu.

### Odpowiedzialność
- uruchamianie workerów
- warmup
- retry
- live progress
- zastosowanie session settings
- obsługa `WorkerAssignment`
- wykonywanie `Text` i `StoredProcedure`
- zbieranie `ExecutionSample`
- budowa `StressRunResult`

---

## WorkerAssignmentFactory
**Plik:** `Services/WorkerAssignmentFactory.cs`

Tworzy przypisania workerów dla scenariusza.

### Odpowiedzialność
- buduje listę `WorkerAssignment`
- wspiera scenariusze wymagające różnych ról workerów

---

# 4. Enumy (`Enums`)

## ExecutionMode
**Plik:** `Enums/ExecutionMode.cs`

Typ wykonania komendy SQL.

### Przykłady
- `NonQuery`
- `Scalar`
- `Reader`

---

## ScenarioType
**Plik:** `Enums/ScenarioType.cs`

Typ scenariusza workloadu.

### Przykłady
- `General`
- `BlockingHotRow`
- `DeadlockPair`
- `ReadStorm`
- `WriteStorm`

---

## WorkerRoleType
**Plik:** `Enums/WorkerRoleType.cs`

Typ roli workera w scenariuszu.

### Przykłady
- `Default`
- `Reader`
- `Writer`
- `DeadlockA`
- `DeadlockB`

---

# 5. Najważniejsze klasy z punktu widzenia przepływu Sprintu 6

Jeżeli patrzeć na projekt operacyjnie, to najważniejsze klasy na koniec Sprintu 6 to:

- `Program`
- `RootConfig`
- `StressOptions`
- `ScenarioPlanner`
- `WorkerAssignmentFactory`
- `StressRunner`
- `SqlExecutor`
- `SessionContextLoader`
- `DmvSnapshotCollector`
- `SqlServerEnvironmentCollector`
- `SqlResultRepository`
- `BulkSampleWriter`
- `ReportWriter`
- `MarkdownReportWriter`
- `HtmlReportWriter`
- `RunComparisonService`
- `TrendAnalysisService`
- `RunCommandService`
- `CompareCommandService`
- `TrendCommandService`

---

# 6. Skrócony przepływ działania

Na koniec Sprintu 6 przepływ wygląda tak:

1. `Program` wczytuje `RootConfig`
2. `ConnectionStringFactory` buduje connection string
3. `ScenarioPlanner` tworzy `ScenarioExecutionPlan`
4. `SqlServerEnvironmentCollector` zbiera metadane SQL Server
5. `LifecycleScriptRunner` uruchamia setup
6. `DmvSnapshotCollector` zbiera snapshoty before
7. `StressRunner` wykonuje workload
8. `DmvSnapshotCollector` zbiera snapshoty after
9. `LifecycleScriptRunner` uruchamia cleanup
10. `RunComparisonService` porównuje current run do baseline
11. `TrendAnalysisService` analizuje trend ostatnich runów
12. `ReportWriter`, `MarkdownReportWriter`, `HtmlReportWriter` tworzą raporty
13. `SqlResultRepository` i `BulkSampleWriter` zapisują wyniki do SQL Server

---

# 7. Status architektury na finał Sprintu 6

Na tym etapie projekt ma już:

- działający runner workloadu
- profile JSON
- mixed auth
- retry
- worker assignments
- scenariusze
- lifecycle setup/cleanup
- DMV snapshots
- SQL metadata
- raporty JSON/CSV/Markdown/HTML
- compare current vs baseline
- trend analysis ostatnich runów
- zapis compare do SQL Server
- bazę pod rozbudowę CLI o osobne komendy `run`, `compare`, `trend`

---

# 8. Podsumowanie

Na koniec Sprintu 6 `SqlStressLab` jest już nie tylko generatorem obciążenia, ale także małym frameworkiem do:

- wykonywania laboratoryjnych testów SQL Server,
- zbierania wyników,
- porównywania uruchomień,
- śledzenia trendów wydajności,
- generowania raportów technicznych.

dotnet publish .\src\SqlStressLab.Cli\SqlStressLab.Cli.csproj `
  -c Release `
  -r win-x64 `
  --self-contained true `
  -o .\publish\SqlStressLab-win-x64
  New-Item -ItemType Directory -Force .\publish\SqlStressLab-win-x64\outputs
New-Item -ItemType Directory -Force .\publish\SqlStressLab-win-x64\logs
New-Item -ItemType Directory -Force .\publish\SqlStressLab-win-x64\sessions
New-Item -ItemType Directory -Force .\publish\SqlStressLab-win-x64\exports
