# Stage 4 - SSIS package executed through SQL Agent Proxy

Cel tego etapu: potwierdzić pełny przepływ wykonawczy **SQL Agent -> SSIS Proxy -> SSISDB -> pakiet -> \\DC01\SSISLab$** bez delegowania tożsamości konta aplikacyjnego.

## Założone nazwy POC

- konto wykonawcze: `SQLLAB\poc-ssis-export`
- Credential: `POC_SSIS_Export_Credential`
- Proxy: `POC_SSIS_Export_Proxy`
- SSISDB folder: `POC_SSIS_Export`
- SSIS project: `POC_SSIS_Export`
- package: `WriteShareTest.dtsx`
- project parameter: `OutputShare`
- test share: `\\DC01\SSISLab$`
- SQL Agent job: `POC_SSIS_Secure_Export_Stage4`

## 1. Utwórz minimalny projekt SSIS w Visual Studio / SSDT

Utwórz Integration Services Project o nazwie `POC_SSIS_Export`.

W projekcie:

1. Dodaj project parameter `OutputShare` typu `String`.
2. Ustaw wartość projektową na `\\DC01\SSISLab$`.
3. Zmień nazwę pakietu na `WriteShareTest.dtsx`.
4. Dodaj `Script Task`.
5. W `ReadOnlyVariables` wskaż `$Project::OutputShare`.
6. W Script Task podmień zawartość `Main()` kodem z pliku `stage4-script-task-main.cs`.

Skrypt tworzy plik tekstowy o nazwie `ssis-proxy-test-yyyyMMdd-HHmmss-fff.txt` w udziale przekazanym parametrem projektu.

## 2. Deploy do SSISDB

Utwórz w SSISDB folder `POC_SSIS_Export` i wdroż projekt `POC_SSIS_Export`.

Po deploy sprawdź w SSMS:

```text
Integration Services Catalogs
  SSISDB
    POC_SSIS_Export
      Projects
        POC_SSIS_Export
          Packages
            WriteShareTest.dtsx
```

Nie uruchamiaj jeszcze pakietu z SQL Agenta.

## 3. Minimalne prawa konta Proxy w SSISDB

Uruchom jako administrator SQL Server:

```text
13-grant-stage4-ssisdb-rights.sql
```

Skrypt:

- tworzy Windows login `SQLLAB\poc-ssis-export`, jeśli go nie ma,
- tworzy użytkownika w SSISDB,
- nadaje tylko `READ` i `EXECUTE` do projektu `POC_SSIS_Export`,
- nie nadaje `db_owner`, `ssis_admin`, `sysadmin` ani praw do innych projektów.

## 4. Utwórz SQL Agent Job

Uruchom:

```text
14-create-stage4-job.sql
```

Job ma jeden krok typu `SSIS`, uruchamiany jako `POC_SSIS_Export_Proxy`.

Pakiet jest uruchamiany z SSISDB, a `OutputShare` jest jawnie ustawiany na `\\DC01\SSISLab$` w definicji kroku. Konto aplikacyjne nie ma dostępu do tego joba ani do udziału.

## 5. Test

Uruchom:

```text
15-test-stage4.sql
```

Skrypt uruchamia job, czeka na zakończenie (maks. 120 sekund), pokazuje ostatnią historię joba oraz ostatnie wykonania SSISDB.

Oczekiwany rezultat:

```text
JobOutcome = Succeeded
```

oraz na `\\DC01\SSISLab$` powinien pojawić się plik:

```text
ssis-proxy-test-yyyyMMdd-HHmmss-fff.txt
```

W środku powinny znaleźć się m.in. `MachineName`, `WindowsIdentity` i czas wykonania. `WindowsIdentity` powinno wskazywać konto wykonawcze `SQLLAB\poc-ssis-export`.

## Granica Stage 4

Stage 4 **nie pobiera jeszcze rekordów z `dbo.ExportRequest`**. Najpierw potwierdzamy sam tor wykonawczy SSIS i tożsamość Proxy.

Dopiero Stage 5 połączy kolejkę z jobem/workerem i będzie zmieniał statusy `NEW -> RUNNING -> COMPLETED/FAILED`.