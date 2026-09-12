# Secure SSIS Export POC

POC bezpiecznego uruchamiania eksportu SSIS bez `Unconstrained Delegation` dla konta aplikacyjnego.

## Cel

Docelowy przepływ:

```text
Windows application
    |
    | Windows Authentication
    v
SQL Server
    |
    | dbo.usp_RequestExport
    v
ExportRequest queue
    |
    v
SQL Server Agent Job
    |
    | SSIS Proxy / dedicated service account
    v
SSIS package
    |
    v
Network share
```

Konto aplikacyjne kończy swoją rolę na SQL Serverze. Nie jest delegowane do SSIS ani do udziału sieciowego.

## Środowisko POC

- domena AD: `SQLLAB.LOCAL`
- konto aplikacyjne: `SQLLAB\poc-ssis-app`
- konto wykonawcze: `SQLLAB\poc-ssis-export`
- baza POC: `SSIS_Delegation_Lab`
- testowy udział SMB: `\\DC01\SSISLab$`

## Stage 1 - warstwa SQL

1. `01-create-database.sql`
2. `02-create-schema.sql`
3. `03-create-request-procedure.sql`
4. `04-test-stage1.sql`

Rezultat: aplikacja może utworzyć rekord `NEW` w `dbo.ExportRequest`, a `RequestedBy` przechowuje `ORIGINAL_LOGIN()`.

## Stage 2 - konto aplikacyjne i minimalne uprawnienia

5. `05-create-application-security.sql`
6. `06-test-application-security.sql`

Rezultat:

```text
CanExecuteRequestProcedure = 1
CanSelectQueue             = 0
CanInsertQueue             = 0
CanUpdateQueue             = 0
CanDeleteQueue             = 0
```

## Stage 3 - konto wykonawcze, SMB, Credential i Proxy

7. `07-create-export-account.ps1`
8. `08-create-test-share.ps1`
9. `09-test-share-access.ps1`
10. `10-create-sql-agent-credential.ps1`
11. `11-create-ssis-proxy.sql`
12. `12-verify-stage3.sql`

Szczegóły: `STAGE3.md`.

Rezultat: `SQLLAB\poc-ssis-export` może zapisywać do `\\DC01\SSISLab$`, Credential i Proxy działają, a Proxy ma wyłącznie subsystem `SSIS`.

## Stage 4 - pierwszy pakiet SSIS przez Proxy

13. `13-grant-stage4-ssisdb-rights.sql`
14. `14-create-stage4-job.sql`
15. `15-test-stage4.sql`

Dodatkowo:

- `stage4-script-task-main.cs` - kod minimalnego Script Task,
- `STAGE4.md` - instrukcja utworzenia, wdrożenia i przetestowania pakietu `WriteShareTest.dtsx`.

Rezultat Stage 4 ma potwierdzić:

```text
SQL Agent
  -> POC_SSIS_Export_Proxy
  -> SQLLAB\poc-ssis-export
  -> SSISDB package
  -> \\DC01\SSISLab$
```

## Założenia bezpieczeństwa

- aplikacja nie przekazuje ścieżki UNC,
- aplikacja nie uruchamia bezpośrednio pakietu SSIS,
- konto aplikacyjne nie otrzymuje praw do SQL Agenta, Credential, Proxy, SSISDB ani udziału,
- aplikacja nie ma bezpośredniego dostępu do tabeli kolejki,
- `ORIGINAL_LOGIN()` służy do audytu zlecającego,
- konto wykonawcze jest oddzielone od konta aplikacyjnego,
- konta POC nie wymagają `Unconstrained Delegation`,
- hasła nie są przechowywane w repozytorium.

## Następny etap

Stage 5 połączy działający tor SSIS z `dbo.ExportRequest` i doda obsługę statusów `NEW -> RUNNING -> COMPLETED/FAILED`, retry oraz kontrolę współbieżności.