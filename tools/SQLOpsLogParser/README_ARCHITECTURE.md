# Architektura projektu `SqlOpsLogParser`

## 1. Cel architektury

Architektura `SqlOpsLogParser` została zaprojektowana jako **modularne narzędzie CLI do diagnostyki operacyjnej SQL Server**, którego zadaniem jest:

- odczyt i analiza `SQL Server ErrorLog`,
- analiza `SQL Server Agent jobs`,
- analiza historii kroków jobów,
- korelacja zdarzeń z różnych źródeł w postaci timeline,
- generowanie raportów operacyjnych,
- eksport wyników do plików.

To nie jest aplikacja webowa ani UI desktopowe. To jest **narzędzie konsolowe**.

## 2. Główne założenia architektoniczne

### 2.1 CLI jako punkt wejścia
Cała aplikacja działa jako `dotnet run` albo opublikowany `exe` / `dll`.

### 2.2 Rozdzielenie domeny od infrastruktury
Kod jest podzielony na warstwy:
- domenową,
- infrastrukturalną,
- wejścia CLI,
- raportowania.

### 2.3 Prosta architektura warstwowa
`Core` definiuje kontrakty i modele, `Infrastructure` realizuje odczyt danych z SQL Server, `Cli` odpowiada za interpretację komend i prezentację, a `Reporting` za zapis raportów.

### 2.4 SQL Server jako główne źródło danych
Główne źródła danych to:
- `sp_enumerrorlogs`
- `xp_readerrorlog`
- `msdb.dbo.sysjobs`
- `msdb.dbo.sysjobhistory`
- `msdb.dbo.sysjobsteps`

## 3. Struktura solution

### 3.1 `SqlOpsLogParser.Cli`
Warstwa wejściowa aplikacji. Odpowiada za host, DI, odczyt argumentów CLI, dispatch komend, renderowanie wyników i podstawową walidację parametrów.

### 3.2 `SqlOpsLogParser.Core`
Warstwa domenowa i kontraktowa. Zawiera modele, enumy, interfejsy i kontrakty między warstwami.

### 3.3 `SqlOpsLogParser.Infrastructure`
Warstwa implementacyjna dla SQL Server i logiki technicznej. Zawiera połączenia, repozytoria, serwisy analityczne i klasyfikację logów.

### 3.4 `SqlOpsLogParser.Reporting`
Warstwa odpowiedzialna za zapis raportów do Markdown, JSON i CSV.

### 3.5 `SqlOpsLogParser.Tests`
Miejsce na testy helperów, klasyfikacji, parserów parametrów i formatterów.

## 4. Przepływ danych w aplikacji

1. Użytkownik uruchamia komendę CLI.
2. `Program.cs` buduje host i DI.
3. `CliApplication` dispatchuje komendę do odpowiedniego handlera.
4. Handler interpretuje argumenty i buduje request.
5. Handler woła serwis lub repozytorium.
6. `Infrastructure` pobiera dane z SQL Server.
7. Handler renderuje wynik do konsoli albo zapisuje raport do pliku.

## 5. Warstwa CLI — szczegółowo

### `Program.cs`
Bootstrap aplikacji, konfiguracja, logger, DI, globalny `try/catch`.

### `CliApplication`
Centralny router komend.

### Handlery
- `ProfilesCommandHandler`
- `ErrorLogCommandHandler`
- `JobsCommandHandler`
- `TimelineCommandHandler`
- `ReportCommandHandler`

## 6. Warstwa domenowa `Core`

Zawiera modele wejścia i wyjścia, modele domenowe, enumy i interfejsy. `Core` nie powinien znać `SqlConnection`, Dappera, Spectre.Console ani Seriloga.

## 7. Warstwa `Infrastructure`

Najważniejsze elementy:
- `SqlConnectionFactory`
- `ConnectionTestService`
- `ErrorLogRepository`
- `ErrorLogReader`
- `LogEntryClassifier`
- `JobRepository`
- `TimelineService`
- `OperationalReportService`

## 8. Warstwa `Reporting`

Najważniejsze elementy:
- `IReportWriter`
- `MarkdownReportWriter`
- `JsonReportWriter`
- `CsvReportWriter`
- `ReportWriterFactory`
- `ReportService`

## 9. Dependency Injection

Projekt jest spięty przez DI. W praktyce dominują `AddSingleton(...)`, co jest wystarczające dla krótkotrwałej aplikacji CLI.

## 10. Konfiguracja

Główna konfiguracja połączeń znajduje się w `profiles.json`. W repo warto trzymać `profiles.sample.json`, a lokalny `profiles.json` ignorować w `.gitignore`.

## 11. Obsługa błędów

Są dwa poziomy obsługi błędów:
- lokalne błędy w handlerach,
- globalne błędy w `Program.cs`.

## 12. Exit codes

Przykładowy zestaw:
- `0` — sukces
- `1` — błąd ogólny
- `2` — błąd połączenia
- `3` — brak danych
- `4` — błąd walidacji parametrów

## 13. Główne moduły funkcjonalne

- Connectivity
- ErrorLog
- SQL Agent
- Timeline
- Reporting

## 14. Zalety tej architektury

- czytelność,
- rozszerzalność,
- automatyzowalność,
- praktyczność,
- dobre rozdzielenie raportowania.

## 15. Ograniczenia obecnej architektury

- brak pełnego parsera pluginowego,
- brak zaawansowanego cache,
- brak wieloźródłowej konfiguracji,
- prosty Markdown writer dla raportów zagnieżdżonych,
- brak integracji z mail/Teams/Slack.

## 16. Możliwe kierunki rozwoju architektury

- konfigurowalne reguły klasyfikacji,
- specjalizowane report writery,
- integracje zewnętrzne,
- scheduler / automation pack,
- nowe źródła danych.

## 17. Podsumowanie architektury

`SqlOpsLogParser` jest zbudowany jako **modularne narzędzie CLI o architekturze warstwowej**, gdzie:
- `Cli` odpowiada za wejście i prezentację,
- `Core` definiuje modele i kontrakty,
- `Infrastructure` realizuje dostęp do SQL Server i logikę techniczną,
- `Reporting` odpowiada za eksport i raporty.
