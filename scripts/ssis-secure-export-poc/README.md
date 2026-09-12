# Secure SSIS Export POC

POC bezpiecznego uruchamiania eksportu bez `Unconstrained Delegation` dla konta aplikacyjnego.

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
    | dedicated execution identity
    v
executor (SSIS / CmdExec)
    |
    v
Network share
```

Konto aplikacyjne kończy swoją rolę na SQL Serverze. Nie jest delegowane do SSIS ani do udziału sieciowego.

## Środowisko POC

- serwer SQL/Agent: `SQL64`
- domena AD: `SQLLAB.LOCAL`
- konto aplikacyjne: `SQLLAB\poc-ssis-app`
- konto wykonawcze: `SQLLAB\poc-ssis-export`
- baza POC: `SSIS_Delegation_Lab`
- testowy udział SMB: `\\DC01\SSISLab$`
- SSISDB: nieużywane w tym POC

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

Rezultat: `SQLLAB\poc-ssis-export` może zapisywać do `\\DC01\SSISLab$`, Credential działa, a SQL Agent może uruchomić krok pod dedykowaną tożsamością.

## Stage 4 - proof of execution identity przez CmdExec Proxy

Na `SQL64` subsystem `SSIS` istnieje, ale nie ma pełnego object modelu SSIS (`Microsoft.SqlServer.ManagedDTS.dll`) ani SSDT. Nie instalujemy dodatkowych komponentów wyłącznie na potrzeby POC.

Dlatego Stage 4 używa `CmdExec Proxy`, aby jednoznacznie potwierdzić najważniejszy element architektury: konto aplikacyjne nie jest delegowane do udziału SMB, a dostęp do zasobu wykonuje osobne konto techniczne.

Pliki:

- `13-create-cmdexec-proxy.sql` - tworzy `POC_Export_CmdExec_Proxy` na istniejącym Credential,
- `14-create-stage4-job.sql` - tworzy job `CmdExec` uruchamiający PowerShell przez Proxy,
- `15-test-stage4.sql` - uruchamia job i sprawdza wynik,
- `STAGE4.md` - pełny runbook.

Rezultat Stage 4 ma potwierdzić:

```text
SQL Agent
  -> POC_Export_CmdExec_Proxy
  -> SQLLAB\poc-ssis-export
  -> PowerShell
  -> \\DC01\SSISLab$
```

W pliku wynikowym sprawdzamy m.in.:

```text
WindowsIdentity=SQLLAB\poc-ssis-export
```

Na środowisku z pełnym SSIS executor `CmdExec` można zastąpić krokiem `SSIS`, zachowując ten sam model Credential/Proxy i tę samą dedykowaną tożsamość wykonawczą.

## Założenia bezpieczeństwa

- aplikacja nie przekazuje ścieżki UNC,
- aplikacja nie uruchamia bezpośrednio SQL Agenta,
- konto aplikacyjne nie otrzymuje praw do Credential, Proxy ani udziału,
- aplikacja nie ma bezpośredniego dostępu do tabeli kolejki,
- `ORIGINAL_LOGIN()` służy do audytu zlecającego,
- konto wykonawcze jest oddzielone od konta aplikacyjnego,
- konta POC nie wymagają `Unconstrained Delegation`,
- hasła nie są przechowywane w repozytorium.

## Następny etap

Stage 5 połączy działający model wykonawczy z `dbo.ExportRequest` i doda obsługę statusów `NEW -> RUNNING -> COMPLETED/FAILED`, retry oraz kontrolę współbieżności.
