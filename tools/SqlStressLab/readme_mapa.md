# SqlStressLab — mapa zależności klas na finał Sprintu 4

Ten dokument pokazuje, jak klasy w `SqlStressLab` są ze sobą powiązane na koniec Sprintu 4.

Nie jest to diagram UML 1:1, tylko praktyczna mapa zależności:
- kto jest punktem wejścia,
- kto kogo wywołuje,
- które klasy są modelami,
- które klasy są usługami wykonawczymi,
- które klasy odpowiadają za raportowanie i zapis do SQL Server.

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
 ├─ ReportWriter
 ├─ MarkdownReportWriter
 ├─ HtmlReportWriter
 ├─ SqlResultRepository
 └─ BulkSampleWriter
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
- `ReportWriter`
- `MarkdownReportWriter`
- `HtmlReportWriter`
- `SqlResultRepository`
- `BulkSampleWriter`

### Dostarcza dane do
- `StressOptions`
- `StressRunRecord`
- `StressRunSampleRecord`
- raportów
- zapisu do SQL Server

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
- `EnvironmentInfo` / opcje środowiskowe
- `MarkdownReportOptions`
- `HtmlReportOptions`
- `TagOptions`
- `List<SqlParameterDefinition>`

### Używany przez
- `Program`
- pośrednio przez `ScenarioPlanner`
- pośrednio przez `StressOptions`

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

# 8. Raportowanie plikowe

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

### Używany przez
- `Program`

---

# 9. Zapis do SQL Server

## SqlResultRepository
**Rola:** zapis i odczyt nagłówków runów oraz snapshotów DMV.

### Zależy od
- `StressRunRecord`
- `StressRunSampleRecord`
- `DmvSnapshotRow`

### Używany przez
- `Program`

### Obsługuje
- `InsertRunAsync`
- `InsertSamplesAsync`
- `InsertDmvSnapshotsAsync`
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

# 10. Widok zależności w układzie warstw

## Warstwa wejściowa
- `Program`
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

## Warstwa raportowania
- `ReportWriter`
- `MarkdownReportWriter`
- `HtmlReportWriter`

## Warstwa persistence
- `SqlResultRepository`
- `BulkSampleWriter`
- `StressRunRecord`
- `StressRunSampleRecord`

---

# 11. Najważniejsze relacje „kto woła kogo”

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

## Zapis do SQL
```text
Program
 ├─ StressRunRecord
 ├─ StressRunSampleRecord
 ├─ SqlResultRepository
 └─ BulkSampleWriter
```

## Raportowanie
```text
Program
 ├─ ReportWriter
 ├─ MarkdownReportWriter
 │   ├─ StressRunRecord
 │   └─ ExecutionSample
 └─ HtmlReportWriter
     ├─ StressRunRecord
     ├─ SqlServerEnvironmentInfo
     ├─ ExecutionSample
     └─ DmvSnapshot
```

---

# 12. Klasy centralne architektury Sprintu 4

Jeśli patrzeć tylko na klasy-klucze, to rdzeń Sprintu 4 stanowią:

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
- `MarkdownReportWriter`
- `HtmlReportWriter`

---

# 13. Podsumowanie

Na koniec Sprintu 4 projekt ma już czytelny podział:

- **Program** — orkiestracja
- **Modele** — dane wejściowe, pośrednie i wynikowe
- **Services** — logika działania
- **Runner** — wykonywanie workloadu
- **Scenario system** — planowanie scenariuszy
- **Reporting** — pliki i HTML/Markdown
- **Persistence** — zapis do SQL Server
- **DMV & SQL metadata** — diagnostyka i analiza środowiska


