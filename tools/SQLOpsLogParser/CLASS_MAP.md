# SqlOpsLogParser — spis klas i mapa zależności

## Cel dokumentu

Ten dokument opisuje:
- główne klasy projektu,
- ich podział na warstwy,
- zależności pomiędzy klasami,
- przepływ odpowiedzialności w aplikacji.

Dokument ma pomóc w:
- orientacji w solution,
- dalszej rozbudowie projektu,
- dokumentacji technicznej,
- onboardingu do projektu.

---

# 1. Podział klas według projektów

## 1.1 `SqlOpsLogParser.Cli`

Warstwa wejściowa aplikacji.

### Klasy
- `CliApplication`
- `ProfilesCommandHandler`
- `ErrorLogCommandHandler`
- `JobsCommandHandler`
- `TimelineCommandHandler`
- `ReportCommandHandler`
- `ServiceCollectionExtensions`

### Rola
Warstwa CLI:
- przyjmuje argumenty,
- wybiera komendę,
- waliduje parametry,
- wywołuje serwisy i repozytoria,
- renderuje wynik do konsoli,
- inicjuje eksport raportów.

---

## 1.2 `SqlOpsLogParser.Core`

Warstwa domenowa i kontraktowa.

### Modele
- `ServerProfile`
- `ProfilesOptions`
- `ConnectionTestResult`
- `SqlErrorLogInfo`
- `SqlLogEntry`
- `ErrorLogReadRequest`
- `JobInfo`
- `JobExecution`
- `JobStepInfo`
- `JobStepExecution`
- `TimelineEvent`
- `TimelineRequest`
- `ReportRequest`
- `ReportSummary`
- `NightlyReport`
- `IncidentReport`

### Enumy
- `EventSeverity`
- `EventCategory`
- `TimelineSourceType`
- `JobExecutionStatus`
- `ReportFormat`

### Kontrakty / interfejsy
- `IProfileProvider`
- `ISqlConnectionFactory`
- `IConnectionTestService`
- `IErrorLogRepository`
- `IErrorLogReader`
- `ILogEntryClassifier`
- `IJobRepository`
- `ITimelineService`
- `IReportWriter`
- `IReportWriterFactory`
- `IReportService`
- `IOperationalReportService`

### Klasy pomocnicze
- `ExitCodes`

---

## 1.3 `SqlOpsLogParser.Infrastructure`

### Klasy
- `JsonProfileProvider`
- `SqlConnectionFactory`
- `ConnectionTestService`
- `ErrorLogRepository`
- `ErrorLogReader`
- `LogEntryClassifier`
- `JobRepository`
- `TimelineService`
- `OperationalReportService`

---

## 1.4 `SqlOpsLogParser.Reporting`

### Klasy
- `MarkdownReportWriter`
- `JsonReportWriter`
- `CsvReportWriter`
- `ReportWriterFactory`
- `ReportService`

---

## 1.5 `SqlOpsLogParser.Tests`

### Potencjalne klasy testowe
- `LogEntryClassifierTests`
- `TimelineServiceTests`
- `FormatHelpersTests`
- `ArgumentParsingTests`
- `ReportWriterTests`

---

# 2. Spis klas z krótkim opisem

## 2.1 Warstwa CLI

### `CliApplication`
Centralny router komend CLI. Wybiera handler na podstawie pierwszego argumentu.

### `ProfilesCommandHandler`
Obsługuje komendy:
- `profiles list`
- `profiles show`
- `profiles test`

### `ErrorLogCommandHandler`
Obsługuje komendy:
- `errorlog list`
- `errorlog read`

### `JobsCommandHandler`
Obsługuje komendy:
- `jobs list`
- `jobs failed`
- `jobs history`
- `jobs steps`
- `jobs failed-steps`

### `TimelineCommandHandler`
Obsługuje komendę `timeline`.

### `ReportCommandHandler`
Obsługuje komendy:
- `report nightly`
- `report incident`

### `ServiceCollectionExtensions`
Konfiguruje dependency injection dla całej aplikacji.

---

## 2.2 Warstwa Core

### `ServerProfile`
Model pojedynczego profilu połączenia do SQL Server.

### `ProfilesOptions`
Model konfiguracji zawierający kolekcję profili.

### `ConnectionTestResult`
Wynik testu połączenia do SQL Server.

### `SqlErrorLogInfo`
Model opisujący pojedynczy ErrorLog: numer, data, rozmiar.

### `SqlLogEntry`
Model pojedynczego wpisu z `xp_readerrorlog`.

### `ErrorLogReadRequest`
Request do odczytu logu z filtrami.

### `JobInfo`
Model podstawowych informacji o jobie.

### `JobExecution`
Model historii wykonania joba jako całości.

### `JobStepInfo`
Model definicji kroku joba.

### `JobStepExecution`
Model historii wykonania konkretnego kroku joba.

### `TimelineEvent`
Ujednolicony model zdarzenia do wspólnej osi czasu.

### `TimelineRequest`
Request do budowy timeline.

### `ReportRequest`
Request do zapisu raportu do pliku.

### `ReportSummary`
Podsumowanie raportu operacyjnego.

### `NightlyReport`
Raport nocny zawierający summary, timeline, failed jobs i failed steps.

### `IncidentReport`
Raport incydentu zawierający summary, timeline, failed jobs i failed steps.

### `ExitCodes`
Stałe definiujące kody wyjścia aplikacji.

---

## 2.3 Warstwa Infrastructure

### `JsonProfileProvider`
Wczytuje profile połączeń z konfiguracji JSON.

### `SqlConnectionFactory`
Buduje połączenie `SqlConnection` na podstawie `ServerProfile`.

### `ConnectionTestService`
Testuje połączenie do instancji SQL Server.

### `ErrorLogRepository`
Pobiera listę ErrorLogów przez `sp_enumerrorlogs`.

### `ErrorLogReader`
Czyta wpisy ErrorLog przez `xp_readerrorlog`.

### `LogEntryClassifier`
Klasyfikuje wpisy ErrorLog do severity i category.

### `JobRepository`
Pobiera dane o jobach i krokach z `msdb`.

### `TimelineService`
Buduje wspólną oś czasu z ErrorLog, failed jobs i failed steps.

### `OperationalReportService`
Buduje raporty operacyjne: nightly i incident.

---

## 2.4 Warstwa Reporting

### `MarkdownReportWriter`
Zapisuje dane do Markdown.

### `JsonReportWriter`
Zapisuje dane do JSON.

### `CsvReportWriter`
Zapisuje dane do CSV.

### `ReportWriterFactory`
Wybiera writer na podstawie formatu.

### `ReportService`
Deleguje zapis raportu do właściwego writera.

---

# 3. Mapa zależności klas

## 3.1 Główny przepływ aplikacji

```text
Program.cs
  -> ServiceCollectionExtensions
  -> CliApplication
       -> ProfilesCommandHandler
       -> ErrorLogCommandHandler
       -> JobsCommandHandler
       -> TimelineCommandHandler
       -> ReportCommandHandler
```

## 3.2 Mapa zależności warstwy CLI

### `CliApplication`

```text
CliApplication
  -> ProfilesCommandHandler
  -> ErrorLogCommandHandler
  -> JobsCommandHandler
  -> TimelineCommandHandler
  -> ReportCommandHandler
```

### `ProfilesCommandHandler`

```text
ProfilesCommandHandler
  -> IProfileProvider
  -> IConnectionTestService
```

### `ErrorLogCommandHandler`

```text
ErrorLogCommandHandler
  -> IProfileProvider
  -> IErrorLogRepository
  -> IErrorLogReader
  -> IReportService
```

### `JobsCommandHandler`

```text
JobsCommandHandler
  -> IProfileProvider
  -> IJobRepository
  -> IReportService
```

### `TimelineCommandHandler`

```text
TimelineCommandHandler
  -> IProfileProvider
  -> ITimelineService
  -> IReportService
```

### `ReportCommandHandler`

```text
ReportCommandHandler
  -> IProfileProvider
  -> IOperationalReportService
  -> IReportService
```

## 3.3 Mapa zależności warstwy Infrastructure

### `JsonProfileProvider`

```text
JsonProfileProvider
  -> ProfilesOptions
```

### `SqlConnectionFactory`

```text
SqlConnectionFactory
  -> ServerProfile
```

### `ConnectionTestService`

```text
ConnectionTestService
  -> ISqlConnectionFactory
```

### `ErrorLogRepository`

```text
ErrorLogRepository
  -> ISqlConnectionFactory
```

### `ErrorLogReader`

```text
ErrorLogReader
  -> ISqlConnectionFactory
  -> ILogEntryClassifier
```

### `LogEntryClassifier`

```text
LogEntryClassifier
  -> SqlLogEntry
  -> EventSeverity
  -> EventCategory
```

### `JobRepository`

```text
JobRepository
  -> ISqlConnectionFactory
```

### `TimelineService`

```text
TimelineService
  -> IErrorLogReader
  -> IJobRepository
```

### `OperationalReportService`

```text
OperationalReportService
  -> ITimelineService
  -> IJobRepository
```

## 3.4 Mapa zależności warstwy Reporting

### `ReportService`

```text
ReportService
  -> IReportWriterFactory
```

### `ReportWriterFactory`

```text
ReportWriterFactory
  -> IEnumerable<IReportWriter>
       -> MarkdownReportWriter
       -> JsonReportWriter
       -> CsvReportWriter
```

---

# 4. Mapa zależności między warstwami

```text
Cli -> Core
Cli -> Infrastructure (przez DI i interfejsy Core)
Cli -> Reporting

Infrastructure -> Core
Reporting -> Core

Core -> (brak zależności na Infrastructure / Cli / Reporting)
```

---

# 5. Uproszczony diagram architektury

```text
+----------------------+
| SqlOpsLogParser.Cli  |
|----------------------|
| CliApplication       |
| *CommandHandler      |
+----------+-----------+
           |
           v
+----------------------+
| SqlOpsLogParser.Core |
|----------------------|
| Models               |
| Enums                |
| Interfaces           |
| ExitCodes            |
+----+-------------+---+
     |             |
     v             v
+----------------------+      +------------------------+
| Infrastructure       |      | Reporting              |
|----------------------|      |------------------------|
| SqlConnectionFactory |      | MarkdownReportWriter   |
| ErrorLogReader       |      | JsonReportWriter       |
| JobRepository        |      | CsvReportWriter        |
| TimelineService      |      | ReportWriterFactory    |
| OperationalReportSvc |      | ReportService          |
+----------------------+      +------------------------+
```

---

# 6. Mapa zależności funkcjonalnych

## 6.1 Profil połączenia

```text
profiles list/show/test
  -> ProfilesCommandHandler
  -> IProfileProvider
  -> JsonProfileProvider

profiles test
  -> IConnectionTestService
  -> ConnectionTestService
  -> ISqlConnectionFactory
  -> SqlConnectionFactory
```

## 6.2 ErrorLog

```text
errorlog list
  -> ErrorLogCommandHandler
  -> IErrorLogRepository
  -> ErrorLogRepository
  -> sp_enumerrorlogs

errorlog read
  -> ErrorLogCommandHandler
  -> IErrorLogReader
  -> ErrorLogReader
  -> ILogEntryClassifier
  -> LogEntryClassifier
  -> xp_readerrorlog
```

## 6.3 Jobs

```text
jobs list
  -> JobsCommandHandler
  -> IJobRepository
  -> JobRepository
  -> msdb.dbo.sysjobs

jobs failed / history
  -> JobsCommandHandler
  -> IJobRepository
  -> JobRepository
  -> msdb.dbo.sysjobhistory

jobs steps / failed-steps
  -> JobsCommandHandler
  -> IJobRepository
  -> JobRepository
  -> msdb.dbo.sysjobsteps
  -> msdb.dbo.sysjobhistory
```

## 6.4 Timeline

```text
timeline
  -> TimelineCommandHandler
  -> ITimelineService
  -> TimelineService
       -> IErrorLogReader
       -> IJobRepository
```

## 6.5 Reports

```text
report nightly / incident
  -> ReportCommandHandler
  -> IOperationalReportService
  -> OperationalReportService
       -> ITimelineService
       -> IJobRepository

export
  -> IReportService
  -> ReportService
  -> IReportWriterFactory
  -> Markdown/Json/Csv writers
```

---

# 7. Klasy centralne architektonicznie

Najważniejsze klasy w projekcie to:
- `CliApplication`
- `SqlConnectionFactory`
- `JobRepository`
- `ErrorLogReader`
- `LogEntryClassifier`
- `TimelineService`
- `OperationalReportService`
- `ReportService`

---

# 8. Klasy, które warto rozwijać w pierwszej kolejności

Najwięcej wartości przyniesie rozbudowa:
- `LogEntryClassifier`
- `TimelineService`
- `OperationalReportService`
- `MarkdownReportWriter`
- `JobRepository`

---

# 9. Podsumowanie

Architektura `SqlOpsLogParser` opiera się na jasnym podziale odpowiedzialności:
- `Cli` steruje,
- `Core` definiuje,
- `Infrastructure` pobiera i analizuje,
- `Reporting` zapisuje.

Najważniejsze relacje klas wyglądają tak:

```text
CliApplication
  -> *CommandHandler
      -> Interfaces z Core
          -> Implementacje w Infrastructure / Reporting
```

To daje architekturę:
- czytelną,
- modularną,
- łatwą do rozwoju,
- praktyczną operacyjnie.
