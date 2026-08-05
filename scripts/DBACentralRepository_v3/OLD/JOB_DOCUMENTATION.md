# Automatyczna dokumentacja jobów

## Kolejność wdrożenia

1. Uruchom:

```sql
12_Create_Job_Documentation_Lifecycle.sql
```

2. Uruchom generator:

```powershell
.\Export-JobDocumentationPages.ps1 `
    -RepositoryServerInstance 'scrambler\sql2022' `
    -RepositoryDatabase 'DBACentralRepository' `
    -OutputPath '.\ConfluenceExport\03. Dokumentacja jobów'
```

## Struktura wynikowa

```text
03. Dokumentacja jobów
├── PROD
│   └── serwer
│       ├── Backup FULL.html
│       └── Backup LOG.html
├── TEST
└── DEV
```

## Statusy

- `MISSING` — brak wygenerowanej strony.
- `GENERATED` — lokalny HTML został utworzony.
- `IN_REVIEW` — istnieje strona Confluence, ale dokumentacja nie została zatwierdzona.
- `APPROVED` — dokumentacja kompletna i zatwierdzona.
- `OUTDATED` — dokumentacja wymaga ponownego przeglądu.
- `RETIRED` — job nie występuje już w bieżącym katalogu.

## Rejestracja strony Confluence

Po utworzeniu strony:

```sql
EXEC [audit].[usp_RegisterJobConfluencePage]
    @InstanceId = 1,
    @JobId = '00000000-0000-0000-0000-000000000000',
    @ConfluencePageId = N'123456789',
    @ConfluencePageUrl = N'https://confluence.example/pages/viewpage.action?pageId=123456789',
    @PageTitle = N'Backup FULL';
```

## Zatwierdzenie dokumentacji

```sql
EXEC [audit].[usp_ApproveJobDocumentation]
    @InstanceId = 1,
    @JobId = '00000000-0000-0000-0000-000000000000',
    @TechnicalOwner = N'Zespół DBA',
    @BusinessOwner = N'Właściciel aplikacji',
    @Criticality = 'HIGH',
    @ReviewedBy = N'Marcin Pytlik',
    @Notes = N'Dokumentacja sprawdzona i zatwierdzona.';
```

Dopiero zatwierdzenie ustawia:

```text
DocumentationStatus = APPROVED
IsDocumented = 1
```

i pozwala usunąć finding `JOB_NOT_DOCUMENTED` przy następnym audycie.

## Ważne

Generator tworzy pliki HTML gotowe do utworzenia stron, ale nie publikuje ich przez REST API Confluence. Publikacja przez API jest osobnym etapem.
