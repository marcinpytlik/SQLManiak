# Mapowanie jobów SSRS

## Cel

Moduł rozpoznaje joby SQL Server Agent o nazwach GUID utworzone przez
SQL Server Reporting Services i mapuje je na:

- raport,
- ścieżkę raportu,
- subskrypcję,
- właściciela subskrypcji,
- rozszerzenie dostarczania,
- status ostatniego wykonania,
- harmonogram SSRS,
- przyjazną nazwę joba.

Nie zmienia nazw jobów w `msdb`.

## Instalacja

Uruchom:

```sql
15_Create_SSRS_Job_Mapping.sql
```

## Kolekcja

Po zakończeniu głównego kolektora uruchom:

```powershell
.\Collect-SsrsJobMappings.ps1 `
    -RepositoryServerInstance 'scrambler\sql2022' `
    -RepositoryDatabase 'DBACentralRepository'
```

Skrypt użyje ostatniego zakończonego `ScanRunId`.

Możesz również podać konkretny skan:

```powershell
.\Collect-SsrsJobMappings.ps1 `
    -RepositoryServerInstance 'scrambler\sql2022' `
    -RepositoryDatabase 'DBACentralRepository' `
    -ScanRunId 25
```

## Uprawnienia źródłowe

Konto kolektora wymaga:

- odczytu `msdb.dbo.sysjobs`,
- połączenia z bazą `master`,
- odczytu tabel w bazie katalogowej SSRS:
  - `dbo.ReportSchedule`,
  - `dbo.Subscriptions`,
  - `dbo.Catalog`,
  - `dbo.Users`,
  - `dbo.Schedule`.

Najprościej nadać konto kolektora jako użytkownika w bazie `ReportServer`
i przyznać mu wyłącznie `SELECT` do wymaganych tabel lub odpowiednią rolę
odczytową zaakceptowaną w organizacji.

## Widoki

```sql
SELECT *
FROM [report].[vSsrsJobs];

SELECT *
FROM [report].[vUnresolvedGuidJobs];

SELECT *
FROM [report].[vSsrsJobMappingSummary];

SELECT *
FROM [report].[vSsrsJobDocumentationDetails];
```

## SQL Server Agent

Dodaj krok pomiędzy kolektorem głównym a eksportem HTML:

```text
01 - Collect repository
02 - Collect SSRS mappings
03 - Generate job documentation
04 - Export Confluence reports
```

Przykładowa komenda kroku 02:

```cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\DBA\DBACentralRepository_v3\Collect-SsrsJobMappings.ps1" -RepositoryServerInstance "scrambler\sql2022" -RepositoryDatabase "DBACentralRepository"
```

## Eksport do Confluence

Do `Export-ConfluenceReports-v2.ps1` warto dodać:

```powershell
@{
    Section = '02. Rejestr jobów'
    PageTitle = 'Joby SSRS'
    Description = 'Joby techniczne SQL Server Reporting Services wraz z nazwą raportu i subskrypcji.'
    Sql = @'
SELECT *
FROM [report].[vSsrsJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [FriendlyJobName];
'@
},
@{
    Section = '02. Rejestr jobów'
    PageTitle = 'Joby GUID bez mapowania'
    Description = 'Joby o nazwie GUID, dla których nie znaleziono mapowania SSRS.'
    Sql = @'
SELECT *
FROM [report].[vUnresolvedGuidJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@
},
```

## Dokumentacja pojedynczego joba

Generator stron dokumentacyjnych powinien korzystać z:

```sql
[report].[vJobsWithFriendlyName]
```

oraz dodać sekcję szczegółów z:

```sql
[report].[vSsrsJobDocumentationDetails]
```

dla danego `InstanceId` i `JobId`.
