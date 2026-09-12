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

## Stage 1

Pierwszy etap obejmuje wyłącznie warstwę SQL Server:

1. `01-create-database.sql` - tworzy bazę `SSIS_Delegation_Lab`.
2. `02-create-schema.sql` - tworzy kolejkę `dbo.ExportRequest`.
3. `03-create-request-procedure.sql` - tworzy procedurę `dbo.usp_RequestExport`.
4. `04-test-stage1.sql` - wykonuje podstawowe testy funkcjonalne.

## Uruchomienie

Uruchom pliki po kolei jako konto administracyjne SQL Server:

```text
01-create-database.sql
02-create-schema.sql
03-create-request-procedure.sql
04-test-stage1.sql
```

Po wykonaniu testu tabela `dbo.ExportRequest` powinna zawierać rekord ze statusem `NEW` oraz wartością `RequestedBy` odpowiadającą loginowi, który wywołał procedurę.

## Założenia bezpieczeństwa

- aplikacja nie przekazuje ścieżki UNC,
- aplikacja nie uruchamia bezpośrednio pakietu SSIS,
- aplikacja nie otrzymuje uprawnień do SQL Agenta ani SSISDB,
- `ORIGINAL_LOGIN()` służy do audytu zlecającego,
- konto wykonujące pakiet zostanie wydzielone w kolejnym etapie,
- udział sieciowy i SQL Agent Proxy nie są konfigurowane w Stage 1.

## Następny etap

Stage 2 będzie obejmował:

- konto aplikacyjne i minimalne uprawnienia,
- konto techniczne eksportu,
- Credential,
- SQL Agent Proxy,
- testowy udział sieciowy,
- pierwszy pakiet SSIS zapisujący plik.
