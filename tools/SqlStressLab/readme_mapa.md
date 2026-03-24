# SqlStressLab — mapa zależności klas na finał Sprintu 6

Ten dokument pokazuje, jak klasy w `SqlStressLab` są ze sobą powiązane na koniec Sprintu 6.

Nie jest to diagram UML 1:1, tylko praktyczna mapa zależności:
- kto jest punktem wejścia,
- kto kogo wywołuje,
- które klasy są modelami,
- które klasy są usługami wykonawczymi,
- które klasy odpowiadają za raportowanie, compare, trend i zapis do SQL Server.

---

# 1. Widok ogólny

```text
Program
 ├─ RootConfig
 ├─ ConnectionStringFactory
 ├─ EnvironmentCollector
 ├─ ScenarioPlanner
 │   ├─ BuiltInScenarioCatalog
 │   └─ WorkerAssignmentFactory
 ├─ SqlServerEnvironmentCollector
 ├─ LifecycleScriptRunner
 ├─ DmvSnapshotCollector
 ├─ StressRunner
 │   ├─ ConnectionStringFactory
 │   ├─ SessionContextLoader
 │   ├─ ParameterValueFactory
 │   └─ Session settings SQL
 ├─ RunComparisonService
 ├─ TrendAnalysisService
 ├─ ReportWriter
 ├─ MarkdownReportWriter
 ├─ HtmlReportWriter
 ├─ SqlResultRepository
 └─ BulkSampleWriter

CommandDispatcher
 ├─ RunCommandService
 ├─ CompareCommandService
 └─ TrendCommandService
```

---

# 2. Główny punkt wejścia

## Program
**Rola:** orkiestrator całego przepływu.

### Zależy od
- `RootConfig`
- `ConnectionStringFactory`
- `EnvironmentCollector`
- `ScenarioPlanner`
- `SqlServerEnvironmentCollector`
- `LifecycleScriptRunner`
- `DmvSnapshotCollector`
- `StressRunner`
- `RunComparisonService`
- `TrendAnalysisService`
- `ReportWriter`
- `MarkdownReportWriter`
- `HtmlReportWriter`
- `SqlResultRepository`
- `BulkSampleWriter`

### Dostarcza dane do
- `StressOptions`
- `StressRunRecord`
- `StressRunSampleRecord`
- `StressRunComparisonRecord`
- raportów
- zapisu do SQL Server

---

## CommandDispatcher
**Rola:** prosty router komend CLI.

### Zależy od
- `RunCommandService`
- `CompareCommandService`
- `TrendCommandService`
- `CliArguments`

### Używany do
- delegowania komendy `run`
- delegowania komendy `compare`
- delegowania komendy `trend`

---

# 3. Konfiguracja i modele wejściowe

## RootConfig
**Rola:** główny model konfiguracji wczytany z JSON.

### Zawiera
- `SqlAuthOptions`
- `ExecutionConfig`
- `RetryOptions`
- `OutputOptions`
- `SqlOutputOptions`
- `RunLifecycleOptions`
- `EnvironmentInfo`
- `MarkdownReportOptions`
- `HtmlReportOptions`
- `TagOptions`
- `List<SqlParameterDefinition>`
- `CompareOptions`
- `TrendOptions`

### Używany przez
- `Program`
- pośrednio przez `ScenarioPlanner`
- pośrednio przez `StressOptions`

---

## CliArguments
**Rola:** model argumentów przekazywanych do warstwy CLI.

### Zawiera
- `Command`
- `ProfilePath`
- `CurrentRunId`
- `BaselineRunId`
- `ProfileName`
- `Top`
- `IncludeSampleLevelDiff`

### Używany przez
- `CommandDispatcher`
- `RunCommandService`
- `CompareCommandService`
- `TrendCommandService`

---

## SqlAuthOptions
**Rola:** konfiguracja połączenia SQL Server.

### Używany przez
- `ConnectionStringFactory`
- `Program`
- `StressOptions`
- `SqlOutputOptions`

---

## ExecutionConfig
**Rola:** konfiguracja sposobu wykonania workloadu.

### Używany przez
- `Program`
- mapowany do `StressOptions`

---

## SqlParameterDefinition
**Rola:** definicja parametru wejściowego do komendy SQL.

### Używany przez
- `Program`
- `StressOptions`
- `ParameterValueFactory`
- `StressRunner`
- `SqlExecutor`

---

## RetryOptions
**Rola:** zasady retry.

### Używany przez
- `Program`
- `StressRunner`

---

## OutputOptions
**Rola:** opcje zapisu plików.

### Używany przez
- `Program`
- `ReportWriter`

---

## SqlOutputOptions
**Rola:** opcje zapisu do SQL Server.

### Używany przez
- `Program`
- `SqlResultRepository`
- `BulkSampleWriter`

---

## RunLifecycleOptions
**Rola:** konfiguracja setup/cleanup.

### Używany przez
- `Program`
- `LifecycleScriptRunner`

---

## MarkdownReportOptions
**Rola:** konfiguracja raportu Markdown.

### Używany przez
- `Program`
- `MarkdownReportWriter`

---

## HtmlReportOptions
**Rola:** konfiguracja raportu HTML.

### Używany przez
- `Program`
- `HtmlReportWriter`

---

## TagOptions
**Rola:** lista tagów runu.

### Używany przez
- `Program`
- `StressRunRecord`

---

## CompareOptions
**Rola:** konfiguracja porównania current vs baseline.

### Zawiera
- `Enabled`
- `Mode`
- `BaselineRunId`
- `IncludeSampleLevelDiff`

### Używany przez
- `Program`

---

## TrendOptions
**Rola:** konfiguracja analizy trendu.

### Zawiera
- `Enabled`
- `Top`

### Używany przez
- `Program`

---

# 4. Planowanie scenariusza

## ScenarioPlanner
**Rola:** buduje finalny plan wykonania scenariusza.

### Zależy od
- `RootConfig`
- `BuiltInScenarioCatalog`
- `WorkerAssignmentFactory`

### Zwraca
- `ScenarioExecutionPlan`

---

## BuiltInScenarioCatalog
**Rola:** katalog wbudowanych scenariuszy.

### Zwraca
- `ScenarioDefinition`

### Używany przez
- `ScenarioPlanner`

---

## WorkerAssignmentFactory
**Rola:** buduje przypisania workerów.

### Zależy od
- `ScenarioDefinition`
- liczby workerów

### Zwraca
- `List<WorkerAssignment>`

### Używany przez
- `ScenarioPlanner`

---

## ScenarioDefinition
**Rola:** definicja scenariusza.

### Używany przez
- `BuiltInScenarioCatalog`
- `ScenarioPlanner`
- `ScenarioExecutionPlan`

---

## ScenarioExecutionPlan
**Rola:** finalny plan scenariusza.

### Zawiera
- `ScenarioDefinition`
- `List<WorkerAssignment>`
- `EffectiveSetupScriptFile`
- `EffectiveCleanupScriptFile`

### Używany przez
- `Program`
- `StressRunner`

---

## WorkerAssignment
**Rola:** przypisanie roli i override dla workera.

### Używany przez
- `WorkerAssignmentFactory`
- `ScenarioExecutionPlan`
- `StressRunner`

---

# 5. Budowanie połączenia i środowiska

## ConnectionStringFactory
**Rola:** tworzy connection string.

### Zależy od
- `SqlAuthOptions`

### Używany przez
- `Program`
- `StressRunner`

---

## EnvironmentCollector
**Rola:** zbiera dane środowiska klienta.

### Zwraca
- `EnvironmentInfo`

### Używany przez
- `Program`

---

## EnvironmentInfo
**Rola:** model środowiska klienta.

### Używany przez
- `Program`
- `StressRunRecord`

---

## SqlServerEnvironmentCollector
**Rola:** zbiera metadane środowiska SQL Server.

### Zwraca
- `SqlServerEnvironmentInfo`

### Używany przez
- `Program`
- `HtmlReportWriter`
- `StressRunRecord`

---

## SqlServerEnvironmentInfo
**Rola:** model środowiska SQL Server.

### Używany przez
- `Program`
- `StressRunRecord`
- `HtmlReportWriter`

---

# 6. Lifecycle i snapshoty

## LifecycleScriptRunner
**Rola:** uruchamia SQL setup/cleanup z plików.

### Zależy od
- connection string
- ścieżka do pliku `.sql`

### Używany przez
- `Program`

---

## DmvSnapshotCollector
**Rola:** zbiera snapshoty DMV.

### Zwraca
- `List<DmvSnapshot>`

### Używany przez
- `Program`
- `SqlResultRepository`
- `HtmlReportWriter`

---

## DmvSnapshot
**Rola:** logiczny snapshot grupujący wiersze DMV.

### Zawiera
- metadane snapshotu
- `List<DmvSnapshotRow>`

### Używany przez
- `Program`
- `DmvSnapshotCollector`
- `HtmlReportWriter`

---

## DmvSnapshotRow
**Rola:** pojedynczy rekord DMV do zapisu.

### Używany przez
- `DmvSnapshot`
- `SqlResultRepository`

---

# 7. Wykonanie workloadu

## StressRunner
**Rola:** główny silnik workloadu.

### Zależy od
- `StressOptions`
- `RetryOptions`
- `List<WorkerAssignment>`
- `ConnectionStringFactory`
- `SessionContextLoader`
- `ParameterValueFactory`

### Zwraca
- `StressRunResult`

### Tworzy / używa
- `ExecutionSample`
- `StressSummary`
- `ProgressSnapshot`

---

## StressOptions
**Rola:** finalny model opcji uruchomienia workloadu.

### Budowany przez
- `Program`

### Używany przez
- `StressRunner`

---

## SessionContextLoader
**Rola:** pobiera dane sesji SQL.

### Zwraca
- `SessionInfo`

### Używany przez
- `StressRunner`

---

## SessionInfo
**Rola:** model kontekstu sesji SQL.

### Używany przez
- `SessionContextLoader`
- `StressRunner`

---

## ParameterValueFactory
**Rola:** generuje wartości parametrów SQL.

### Zależy od
- `SqlParameterDefinition`
- `workerId`
- `iteration`

### Używany przez
- `StressRunner`
- `SqlExecutor`

---

## SqlExecutor
**Rola:** warstwa wykonania pojedynczej komendy SQL.

### Zależy od
- `SqlConnection`
- `StressOptions`
- `SqlParameterDefinition`
- `ParameterValueFactory`

### Używany przez
- logicznie przez `StressRunner`
- albo jako pomocniczy executor w projekcie

---

## ExecutionSample
**Rola:** wynik pojedynczego wykonania.

### Tworzony przez
- `StressRunner`

### Używany przez
- `StressRunResult`
- `ReportWriter`
- `MarkdownReportWriter`
- `HtmlReportWriter`
- `BulkSampleWriter`
- `StressRunSampleRecord`

---

## ProgressSnapshot
**Rola:** snapshot postępu do konsoli.

### Tworzony przez
- `StressRunner`

### Używany przez
- `Program`

---

## StressSummary
**Rola:** summary runu.

### Tworzony przez
- `StressRunner`
- `MetricsCalculator`

### Używany przez
- `StressRunResult`
- `Program`
- `ReportWriter`

---

## StressRunResult
**Rola:** pełny wynik runu z runnera.

### Zawiera
- `RunId`
- `StartedAtUtc`
- `FinishedAtUtc`
- `RetryCount`
- `StressSummary`
- `List<ExecutionSample>`

### Tworzony przez
- `StressRunner`

### Używany przez
- `Program`

---

## MetricsCalculator
**Rola:** liczenie statystyk z próbek.

### Używany przez
- `StressRunner`
- ewentualnie inne warstwy raportowania

---

# 8. Compare i trend

## RunComparisonService
**Rola:** wykonuje porównanie current run vs baseline.

### Zależy od
- `StressRunRecord`
- `RunComparisonResult`

### Zwraca
- `RunComparisonResult`

### Używany przez
- `Program`

---

## RunComparisonResult
**Rola:** wynik porównania dwóch runów.

### Zawiera
- `RunId`
- `BaselineRunId`
- profile i scenariusze current/baseline
- delty AVG, P95, throughput, errors, retries
- `IsRegression`
- `SummaryText`

### Używany przez
- `Program`
- `MarkdownReportWriter`
- `HtmlReportWriter`

---

## TrendAnalysisService
**Rola:** analizuje trend ostatnich N runów.

### Zależy od
- `List<StressRunRecord>`
- `TrendPoint`
- `TrendAnalysisResult`

### Zwraca
- `TrendAnalysisResult`

### Używany przez
- `Program`

---

## TrendAnalysisResult
**Rola:** wynik analizy trendu.

### Zawiera
- `ProfileName`
- `RequestedTop`
- `List<TrendPoint>`
- kierunki zmian:
  - `AvgDurationTrendDirection`
  - `P95DurationTrendDirection`
  - `ThroughputTrendDirection`
  - `ErrorTrendDirection`
- `SummaryVerdict`

### Używany przez
- `Program`
- `MarkdownReportWriter`
- `HtmlReportWriter`

---

## TrendPoint
**Rola:** pojedynczy punkt trendu.

### Używany przez
- `TrendAnalysisResult`
- `TrendAnalysisService`
- raporty

---

# 9. Raportowanie plikowe

## ReportWriter
**Rola:** zapis podstawowych artefaktów plikowych.

### Zależy od
- `StressSummary`
- `List<ExecutionSample>`

### Tworzy
- JSON
- CSV
- reader preview

### Używany przez
- `Program`

---

## MarkdownReportWriter
**Rola:** tworzy raport `.md`.

### Zależy od
- `StressRunRecord`
- `List<ExecutionSample>`
- `MarkdownReportOptions`
- `RunComparisonResult`
- `TrendAnalysisResult`

### Używany przez
- `Program`

---

## HtmlReportWriter
**Rola:** tworzy raport `.html`.

### Zależy od
- `StressRunRecord`
- `SqlServerEnvironmentInfo`
- `List<ExecutionSample>`
- `List<DmvSnapshot>`
- `HtmlReportOptions`
- `RunComparisonResult`
- `TrendAnalysisResult`

### Używany przez
- `Program`

---

# 10. Zapis do SQL Server

## SqlResultRepository
**Rola:** zapis i odczyt nagłówków runów, compare oraz snapshotów DMV.

### Zależy od
- `StressRunRecord`
- `StressRunSampleRecord`
- `StressRunComparisonRecord`
- `DmvSnapshotRow`

### Używany przez
- `Program`

### Obsługuje
- `InsertRunAsync`
- `InsertSamplesAsync`
- `InsertDmvSnapshotsAsync`
- `InsertComparisonAsync`
- `GetRunByIdAsync`
- `GetLatestRunByProfileAsync`
- `GetLatestRunsByProfileAsync`

---

## BulkSampleWriter
**Rola:** wydajny zapis próbek do SQL przez `SqlBulkCopy`.

### Zależy od
- `List<StressRunSampleRecord>`

### Używany przez
- `Program`

---

## StressRunRecord
**Rola:** model nagłówka runu do SQL.

### Budowany przez
- `Program`

### Używany przez
- `SqlResultRepository`
- `RunComparisonService`
- `TrendAnalysisService`
- `MarkdownReportWriter`
- `HtmlReportWriter`

---

## StressRunSampleRecord
**Rola:** model próbki do SQL.

### Budowany przez
- `Program` na podstawie `ExecutionSample`

### Używany przez
- `BulkSampleWriter`
- `SqlResultRepository`

---

## StressRunComparisonRecord
**Rola:** model compare do SQL.

### Budowany przez
- `Program` na podstawie `RunComparisonResult`

### Używany przez
- `SqlResultRepository`

---

# 11. Warstwa CLI command services

## RunCommandService
**Rola:** obsługuje komendę `run`.

### Używany przez
- `CommandDispatcher`

---

## CompareCommandService
**Rola:** obsługuje komendę `compare`.

### Używany przez
- `CommandDispatcher`

---

## TrendCommandService
**Rola:** obsługuje komendę `trend`.

### Używany przez
- `CommandDispatcher`

---

# 12. Widok zależności w układzie warstw

## Warstwa wejściowa
- `Program`
- `CommandDispatcher`
- `CliArguments`
- `RootConfig`
- `ExecutionConfig`
- `SqlAuthOptions`
- `RetryOptions`
- `OutputOptions`
- `SqlOutputOptions`
- `RunLifecycleOptions`
- `MarkdownReportOptions`
- `HtmlReportOptions`
- `TagOptions`
- `CompareOptions`
- `TrendOptions`
- `SqlParameterDefinition`

## Warstwa planowania
- `ScenarioPlanner`
- `BuiltInScenarioCatalog`
- `ScenarioDefinition`
- `ScenarioExecutionPlan`
- `WorkerAssignmentFactory`
- `WorkerAssignment`

## Warstwa wykonania
- `StressOptions`
- `StressRunner`
- `SqlExecutor`
- `SessionContextLoader`
- `SessionInfo`
- `ParameterValueFactory`
- `ExecutionSample`
- `StressSummary`
- `StressRunResult`
- `ProgressSnapshot`

## Warstwa środowiska i diagnostyki
- `EnvironmentCollector`
- `EnvironmentInfo`
- `SqlServerEnvironmentCollector`
- `SqlServerEnvironmentInfo`
- `DmvSnapshotCollector`
- `DmvSnapshot`
- `DmvSnapshotRow`

## Warstwa lifecycle
- `LifecycleScriptRunner`

## Warstwa compare i trend
- `RunComparisonService`
- `RunComparisonResult`
- `TrendAnalysisService`
- `TrendAnalysisResult`
- `TrendPoint`

## Warstwa raportowania
- `ReportWriter`
- `MarkdownReportWriter`
- `HtmlReportWriter`

## Warstwa persistence
- `SqlResultRepository`
- `BulkSampleWriter`
- `StressRunRecord`
- `StressRunSampleRecord`
- `StressRunComparisonRecord`

## Warstwa CLI service
- `RunCommandService`
- `CompareCommandService`
- `TrendCommandService`

---

# 13. Najważniejsze relacje „kto woła kogo”

## Główny łańcuch
```text
Program
 └─ ScenarioPlanner
    ├─ BuiltInScenarioCatalog
    └─ WorkerAssignmentFactory

Program
 ├─ EnvironmentCollector
 ├─ SqlServerEnvironmentCollector
 ├─ LifecycleScriptRunner
 ├─ DmvSnapshotCollector
 ├─ StressRunner
 ├─ RunComparisonService
 ├─ TrendAnalysisService
 ├─ ReportWriter
 ├─ MarkdownReportWriter
 ├─ HtmlReportWriter
 ├─ SqlResultRepository
 └─ BulkSampleWriter
```

## Wnętrze runnera
```text
StressRunner
 ├─ ConnectionStringFactory
 ├─ SessionContextLoader
 ├─ ParameterValueFactory
 ├─ ExecutionSample
 ├─ StressSummary
 └─ StressRunResult
```

## Compare i trend
```text
Program
 ├─ RunComparisonService
 │   ├─ StressRunRecord
 │   └─ RunComparisonResult
 └─ TrendAnalysisService
     ├─ StressRunRecord
     ├─ TrendPoint
     └─ TrendAnalysisResult
```

## Zapis do SQL
```text
Program
 ├─ StressRunRecord
 ├─ StressRunSampleRecord
 ├─ StressRunComparisonRecord
 ├─ SqlResultRepository
 └─ BulkSampleWriter
```

## Raportowanie
```text
Program
 ├─ ReportWriter
 ├─ MarkdownReportWriter
 │   ├─ StressRunRecord
 │   ├─ ExecutionSample
 │   ├─ RunComparisonResult
 │   └─ TrendAnalysisResult
 └─ HtmlReportWriter
     ├─ StressRunRecord
     ├─ SqlServerEnvironmentInfo
     ├─ ExecutionSample
     ├─ DmvSnapshot
     ├─ RunComparisonResult
     └─ TrendAnalysisResult
```

## CLI dispatcher
```text
CommandDispatcher
 ├─ RunCommandService
 ├─ CompareCommandService
 └─ TrendCommandService
```

---

# 14. Klasy centralne architektury Sprintu 6

Jeśli patrzeć tylko na klasy-klucze, to rdzeń Sprintu 6 stanowią:

- `Program`
- `RootConfig`
- `ScenarioPlanner`
- `StressOptions`
- `StressRunner`
- `ExecutionSample`
- `StressSummary`
- `StressRunResult`
- `DmvSnapshotCollector`
- `SqlServerEnvironmentCollector`
- `StressRunRecord`
- `SqlResultRepository`
- `BulkSampleWriter`
- `RunComparisonService`
- `RunComparisonResult`
- `TrendAnalysisService`
- `TrendAnalysisResult`
- `MarkdownReportWriter`
- `HtmlReportWriter`
- `CommandDispatcher`

---

# 15. Podsumowanie

Na koniec Sprintu 6 projekt ma czytelny podział:

- **Program** — orkiestracja pełnego runu
- **CommandDispatcher** — routing komend CLI
- **Modele** — dane wejściowe, pośrednie i wynikowe
- **Services** — logika działania
- **Runner** — wykonywanie workloadu
- **Scenario system** — planowanie scenariuszy
- **Compare** — porównanie current vs baseline
- **Trend** — analiza zmian między runami
- **Reporting** — pliki i HTML/Markdown
- **Persistence** — zapis do SQL Server
- **DMV & SQL metadata** — diagnostyka i analiza środowiska

Na tym etapie `SqlStressLab` jest już nie tylko generatorem obciążenia, ale też narzędziem do porównywania wyników i śledzenia trendów kolejnych uruchomień.
