# DBACentralRepository v3

Centralne repozytorium DBA dla SQL Server.

## Moduły

- `dbo` — instancje, środowiska, skany i błędy,
- `job` — SQL Server Agent,
- `db` — bazy i pliki,
- `backup` — backup i restore,
- `capacity` — pojemność,
- `ha` — Availability Groups,
- `maintenance` — CHECKDB i maintenance,
- `patch` — wersje i patching,
- `config` — konfiguracja instancji,
- `security` — loginy, role, proxy i Database Mail,
- `audit` — zgodność, dokumentacja i zmiany,
- `alert` — findingi,
- `report` — raporty.

## Kolejność instalacji

```text
00_Create_Database_And_Schemas.sql
01_Create_Core_Objects.sql
02_Create_Job_And_Database_Modules.sql
03_Create_Stage1_Modules.sql
04_Create_Stage2_Modules.sql
05_Create_Report_Objects.sql
06_Add_Extended_Properties.sql
09_Create_Audit_Compliance.sql
07_Create_Agent_Jobs.sql
```

## Pierwszy skan

```powershell
.\Collect-DBACentralRepository.ps1 `
    -ServerListPath .\Servers.csv `
    -RepositoryServerInstance SQLCENTRAL `
    -CollectionMode Full
```

## Eksport

```powershell
.\Export-ConfluenceReports.ps1 `
    -RepositoryServerInstance SQLCENTRAL `
    -OutputPath .\ConfluenceExport
```

## Ważne

Pierwsze wdrożenie wykonaj na instancji testowej. Kolektor wymaga odpowiednich uprawnień do metadanych instancji, `msdb`, DMV, jobów i bezpieczeństwa.
