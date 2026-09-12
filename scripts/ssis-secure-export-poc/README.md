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
- format loginów Windows w SQL Server: `SQLLAB\<konto>`
- baza POC: `SSIS_Delegation_Lab`

## Stage 1 - warstwa SQL

1. `01-create-database.sql` - tworzy bazę `SSIS_Delegation_Lab`.
2. `02-create-schema.sql` - tworzy kolejkę `dbo.ExportRequest`.
3. `03-create-request-procedure.sql` - tworzy procedurę `dbo.usp_RequestExport`.
4. `04-test-stage1.sql` - wykonuje podstawowe testy funkcjonalne.

Po wykonaniu testu tabela `dbo.ExportRequest` powinna zawierać rekord ze statusem `NEW` oraz wartością `RequestedBy` odpowiadającą loginowi, który wywołał procedurę.

## Stage 2 - konto aplikacyjne i minimalne uprawnienia

5. `05-create-application-security.sql`
   - tworzy login Windows dla konta aplikacyjnego, jeśli jeszcze nie istnieje,
   - tworzy użytkownika w `SSIS_Delegation_Lab`,
   - nadaje wyłącznie `EXECUTE` do `dbo.usp_RequestExport`,
   - jawnie blokuje bezpośredni `SELECT/INSERT/UPDATE/DELETE` do `dbo.ExportRequest`.

6. `06-test-application-security.sql`
   - należy uruchomić w osobnej sesji zalogowanej jako konto aplikacyjne,
   - potwierdza, że procedura może zostać wykonana,
   - potwierdza, że bezpośredni dostęp do kolejki jest zabroniony,
   - wyświetla efektywne prawa przez `HAS_PERMS_BY_NAME`.

### Ważne przed uruchomieniem Stage 2

W pliku `05-create-application-security.sql` zmień jedną wartość:

```sql
DECLARE @AppLogin sysname = N'SQLLAB\konto';
```

na rzeczywisty login konta aplikacyjnego, np.:

```sql
DECLARE @AppLogin sysname = N'SQLLAB\app_ssis_export';
```

Tę samą nazwę należy wykorzystać do zalogowania się podczas testu `06-test-application-security.sql`.

## Kolejność uruchamiania

Jako administrator SQL Server:

```text
01-create-database.sql
02-create-schema.sql
03-create-request-procedure.sql
04-test-stage1.sql
05-create-application-security.sql
```

Następnie jako konto aplikacyjne:

```text
06-test-application-security.sql
```

Oczekiwany wynik końcowy Stage 2:

```text
CanExecuteRequestProcedure = 1
CanSelectQueue             = 0
CanInsertQueue             = 0
CanUpdateQueue             = 0
CanDeleteQueue             = 0
```

## Założenia bezpieczeństwa

- aplikacja nie przekazuje ścieżki UNC,
- aplikacja nie uruchamia bezpośrednio pakietu SSIS,
- aplikacja nie otrzymuje uprawnień do SQL Agenta ani SSISDB,
- aplikacja nie ma bezpośredniego dostępu do tabeli kolejki,
- `ORIGINAL_LOGIN()` służy do audytu zlecającego,
- konto wykonujące pakiet będzie oddzielone od konta aplikacyjnego,
- konto aplikacyjne nie będzie wymagało `Unconstrained Delegation`.

## Następny etap

Stage 3 będzie obejmował:

- dedykowane konto techniczne eksportu,
- Credential,
- SQL Agent Proxy,
- testowy udział sieciowy,
- pierwszy pakiet SSIS zapisujący plik,
- test działania bez delegowania konta aplikacyjnego do zasobu sieciowego.
