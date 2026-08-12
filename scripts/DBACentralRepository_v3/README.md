# DBACentralRepository v3 — kompletna paczka

Centralne repozytorium administracyjne dla floty SQL Server. Paczka zawiera
kolektor, audyt zgodności, klasyfikację jobów, raporty dzienne/tygodniowe/
miesięczne, wykrywanie zmian, automatyczną dokumentację każdego joba oraz
mapowanie technicznych jobów SSRS o nazwach GUID.

## Zawartość

### Skrypty SQL

| Kolejność | Plik | Zakres |
|---:|---|---|
| 00 | `00_Create_Database_And_Schemas.sql` | baza i schematy |
| 01 | `01_Create_Core_Objects.sql` | instancje, środowiska, skany |
| 02 | `02_Create_Job_And_Database_Modules.sql` | joby i bazy |
| 03 | `03_Create_Stage1_Modules.sql` | backup, capacity, HA, maintenance |
| 04 | `04_Create_Stage2_Modules.sql` | patch, config, security, audit |
| 05 | `05_Create_Report_Objects.sql` | podstawowe widoki raportowe |
| 06 | `06_Add_Extended_Properties.sql` | opisy obiektów |
| 07 | `14_Create_Agent_Jobs.sql` | dzienny pipeline SQL Server Agent |
| 08 | `99_Useful_Queries.sql` | zapytania pomocnicze |
| 09 | `07_Create_Audit_Compliance.sql` | reguły i findingi zgodności |
| 10 | `08_Create_Job_Category_Views.sql` | kategorie jobów |
| 11 | `09_Create_Job_Change_Views.sql` | strony zmian |
| 12 | `10_Create_Job_Audit_Compliance_Views.sql` | strony audytu i zgodności |
| 13 | `11_Create_Job_Operational_Report_Procedures.sql` | raport dzienny, tygodniowy i miesięczny |
| 14 | `12_Create_Job_Documentation_Lifecycle.sql` | cykl życia dokumentacji jobów |
| 15 | `13_Create_SSRS_Job_Mapping.sql` | mapowanie GUID jobów SSRS |

### Skrypty PowerShell

- `Collect-DBACentralRepository.ps1` — główny kolektor.
- `Collect-SsrsJobMappings.ps1` — mapowanie GUID → raport/subskrypcja SSRS.
- `Export-JobDocumentationPages.ps1` — osobna strona HTML dla każdego joba.
- `Export-ConfluenceReports.ps1` — raporty HTML/CSV nazwane jak strony Confluence.

### Dokumentacja

- `AUDIT_COMPLIANCE.md`
- `JOB_DOCUMENTATION.md`
- `SSRS_JOB_MAPPING.md`

## Wymagania

- SQL Server 2016 SP1 lub nowszy.
- SQL Server Agent uruchomiony na instancji centralnej.
- PowerShell 5.1 lub 7.
- Konto kolektora z prawami odczytu metadanych źródłowych.
- Konto wykonujące skrypty z prawami zapisu do `DBACentralRepository`.
- Dostęp do katalogu, w którym powstają pliki HTML i CSV.

## Kolejność instalacji

Pełna kolejność znajduje się w `INSTALL_ORDER.md`. Najważniejsza zmiana: `99_Useful_Queries.sql` jest uruchamiany dopiero po utworzeniu wszystkich obiektów.

```text
00–06  Fundament repozytorium
07–13  Audyt, raporty, dokumentacja i SSRS
14     Automatyzacja SQL Server Agent
98     Walidacja instalacji
99     Zapytania użytkowe
```

Wszystkie skrypty tworzące obiekty są idempotentne. Obowiązuje konwencja `[schemat].[Obiekt]`, np. `[backup].[BackupHistory]`.

## Konfiguracja Servers.csv

Przykład:

```csv
ServerInstance,EnvironmentCode,IsActive,CollectSecurity
serwer,port,PROD,1,1
serwerv2,port,1520,PROD,1,1
```

Zachowaj format zgodny z używanym już plikiem. W nazwie instancji z portem
może występować przecinek, dlatego pole powinno być odpowiednio ujęte
w cudzysłów, jeżeli parser CSV tego wymaga:

```csv
ServerInstance,EnvironmentCode,IsActive,CollectSecurity
"serwer,port",PROD,1,1
```

## Pierwsze uruchomienie ręczne

### 1. Główny kolektor

```powershell
.\Collect-DBACentralRepository.ps1 `
    -ServerListPath '.\Servers.csv' `
    -RepositoryServerInstance 'serwer' `
    -RepositoryDatabase 'DBACentralRepository' `
    -CollectionMode Full
```

Główny kolektor sam uruchamia audyt zgodności. Nie uruchamiaj po nim
drugiego audytu w tym samym przebiegu.

### 2. Mapowanie jobów SSRS

```powershell
.\Collect-SsrsJobMappings.ps1 `
    -RepositoryServerInstance 'serwer' `
    -RepositoryDatabase 'DBACentralRepository'
```

Brak bazy `ReportServer` na danej instancji nie jest błędem — instancja
zostanie pominięta. Konto kolektora musi mieć odczyt wymaganych tabel
katalogowych SSRS.

### 3. Dokumentacja każdego joba

```powershell
.\Export-JobDocumentationPages.ps1 `
    -RepositoryServerInstance 'serwer`
    -RepositoryDatabase 'DBACentralRepository' `
    -OutputPath '.\ConfluenceExport\03. Dokumentacja jobów'
```

Wygenerowanie pliku nadaje status `GENERATED`. Job jest uznany za w pełni
udokumentowany dopiero po zarejestrowaniu strony Confluence i zatwierdzeniu:

```text
DocumentationStatus = APPROVED
IsDocumented = 1
```

### 4. Raporty do Confluence

```powershell
.\Export-ConfluenceReports.ps1 `
    -RepositoryServerInstance 'serwer' `
    -RepositoryDatabase 'DBACentralRepository' `
    -OutputPath '.\ConfluenceExport'
```

Struktura wynikowa odpowiada strukturom stron, np.:

```text
ConfluenceExport
├── 01. Dashboard środowiska
├── 02. Rejestr jobów
├── 03. Dokumentacja jobów
├── 08. Monitoring i raportowanie
├── 09. Audyt i zgodność
└── 10. Zmiany i cykl życia
```

W sekcji `08. Monitoring i raportowanie` powstają:

```text
Raport dzienny.html
Raport tygodniowy.html
Raport miesięczny.html
```

## Automatyzacja SQL Server Agent

Skrypt `14_Create_Agent_Jobs.sql` tworzy jeden pipeline:

```text
01 - Collect repository
02 - Collect SSRS mappings
03 - Generate job documentation
04 - Export Confluence reports
```

Na początku skryptu ustaw:

```sql
@BasePath
@RepositoryServer
@RepositoryDatabase
@OwnerLogin
```

Krok SSRS przechodzi dalej również wtedy, gdy nie ma serwera raportowego.
Pozostałe błędy zatrzymują pipeline.

## Joby SSRS o nazwach GUID

Nie zmieniaj ich nazw w `msdb`. Moduł SSRS zapisuje nazwę przyjazną wyłącznie
w centralnym repozytorium:

```text
Nazwa techniczna:
F2317A9C-6C62-4E61-911A-4E6619B71223

Nazwa przyjazna:
SSRS - /Finanse/Raport miesięczny - Wysyłka do księgowości
```

Raporty:

```sql
SELECT * FROM [report].[vSsrsJobs];
SELECT * FROM [report].[vUnresolvedGuidJobs];
SELECT * FROM [report].[vSsrsJobMappingSummary];
```

## Raporty operacyjne

```sql
EXEC [report].[usp_DailyJobControl];
EXEC [report].[usp_WeeklyJobControl];
EXEC [report].[usp_MonthlyJobConfigurationAudit];
```

Raporty korzystają z danych zgromadzonych w repozytorium. Sekcja dotycząca
nieudanych wykonań będzie miarodajna dopiero wtedy, gdy tabela
`job.JobExecution` jest regularnie zasilana historią wykonań.

## Publikacja Confluence

Eksportery tworzą lokalne pliki HTML i CSV gotowe do użycia w Confluence.
Nie publikują jeszcze stron przez REST API. Rejestracja prawdziwego adresu
strony odbywa się procedurą:

```sql
EXEC [audit].[usp_RegisterJobConfluencePage]
    @InstanceId = 1,
    @JobId = '00000000-0000-0000-0000-000000000000',
    @ConfluencePageId = N'123456',
    @ConfluencePageUrl = N'https://confluence.example/page/123456',
    @PageTitle = N'Backup FULL';
```

Następnie dokumentację zatwierdza:

```sql
EXEC [audit].[usp_ApproveJobDocumentation]
    @InstanceId = 1,
    @JobId = '00000000-0000-0000-0000-000000000000',
    @TechnicalOwner = N'Zespół DBA',
    @BusinessOwner = N'Właściciel aplikacji',
    @Criticality = 'HIGH',
    @ReviewedBy = N'Marcin Pytlik';
```

## Ważne ograniczenia obecnej wersji

- Eksport HTML nie aktualizuje automatycznie stron przez REST API Confluence.
- Nie każda nazwa GUID musi pochodzić z SSRS; takie joby trafiają do
  `report.vUnresolvedGuidJobs`.
- Klasyfikacja funkcjonalna jest heurystyczna i może wymagać wyjątków.
- Pierwszy skan stanowi punkt odniesienia; pełne raportowanie zmian wymaga
  co najmniej dwóch poprawnych skanów.
- Wdrożenie najpierw wykonaj na instancji testowej.


## Poprawka kolektora DataTable

W tej wersji `Invoke-Table` zwraca obiekt `DataTable` przez:

```powershell
Write-Output -NoEnumerate $table
```

Zapobiega to automatycznemu rozwinięciu tabeli do `DataRow[]` i błędom:

```text
The property 'Rows' cannot be found on this object
Cannot convert System.Object[] to System.Data.DataTable
```


## Wspólny moduł PowerShell

Wspólne funkcje zostały przeniesione do:

```text
modules
└── DBACentralRepository.Common
    ├── DBACentralRepository.Common.psd1
    └── DBACentralRepository.Common.psm1
```

Moduł zawiera:

- tworzenie połączeń SQL,
- wykonywanie zapytań zwracających `DataTable`,
- `ExecuteScalar` i `ExecuteNonQuery`,
- `SqlBulkCopy`,
- dodawanie kolumn `ScanRunId`, `InstanceId` i `CapturedAt`,
- konwersję `DataTable` do obiektów PowerShell,
- kodowanie HTML,
- bezpieczne nazwy plików i folderów.

Każdy skrypt ładuje moduł względem `$PSScriptRoot`, dlatego nie trzeba
instalować go globalnie. Należy kopiować cały katalog projektu razem
z folderem `modules`.

Przykład:

```powershell
$modulePath = Join-Path `
    $PSScriptRoot `
    'modules\DBACentralRepository.Common\DBACentralRepository.Common.psd1'

Import-Module -Name $modulePath -Force -ErrorAction Stop
```

---

## Grafana i moduł PERF

Od rozszerzenia v3 Grafana może być bezpośrednią warstwą prezentacji danych z repozytorium.

Nowe elementy:

- `20_Create_Perf_Module.sql` – snapshoty CPU/I/O/Buffer Pool/log/concurrency per baza,
- `21_Create_Perf_Retention.sql` – retencja historii performance,
- `Collect-DatabasePerformance.ps1` – lekki collector wydajności,
- `22_Create_Grafana_Views.sql` – warstwa `report.vGrafana*`,
- `23_Create_Perf_Agent_Job.sql` – niezależny harmonogram performance,
- `grafana/*.json` – dashboardy do importu,
- `GRAFANA.md` – konfiguracja datasource i zmiennych.

Confluence nie został usunięty. Dotychczasowe eksporty i joby mogą działać równolegle, a migrację prezentacji do Grafany można przeprowadzić etapami.
