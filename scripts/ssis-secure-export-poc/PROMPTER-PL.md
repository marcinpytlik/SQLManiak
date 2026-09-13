# Prompter: Jak usunąć Unconstrained Delegation z procesu eksportu SQL Server

## Otwarcie

Cześć.

Dzisiaj pokażę Wam przypadek, który zaczyna się od bardzo typowego wymagania:

aplikacja Windows łączy się do SQL Servera, uruchamia eksport, a wynik ma zostać zapisany na udziale sieciowym.

Brzmi prosto.

Problem zaczyna się wtedy, gdy próbujemy przenieść tożsamość użytkownika albo konta aplikacyjnego przez SQL Server dalej, do kolejnego serwera.

I bardzo szybko pojawia się temat Kerberosa, double-hop i delegacji.

W naszym przypadku konto aplikacyjne miało `Unconstrained Delegation`.

Zamiast zastanawiać się, jak tę delegację poprawnie skonfigurować, postawiliśmy inne pytanie:

**czy naprawdę musimy delegować tożsamość aplikacji dalej?**

I odpowiedź brzmi: nie.

---

## Problem

Mamy aplikację Windows działającą pod kontem domenowym.

Aplikacja uwierzytelnia się do SQL Servera przez Windows Authentication.

Następnie wywołuje procedurę, która inicjuje eksport danych.

Wynik eksportu musi trafić na udział SMB na innym serwerze.

Pierwotne podejście można uprościć do takiego schematu:

```text
Application identity
    -> SQL Server
    -> SSIS / proces eksportu
    -> SMB share
```

Czyli próbujemy przenieść tę samą tożsamość przez kilka granic bezpieczeństwa.

To jest dokładnie miejsce, w którym pojawia się problem double-hop.

Jednym ze sposobów obejścia tego problemu jest delegacja Kerberos.

Ale `Unconstrained Delegation` daje zdecydowanie więcej zaufania, niż potrzebujemy do zwykłego wygenerowania pliku.

Dlatego zmieniliśmy architekturę.

---

## Najważniejsza decyzja

Kluczowa zasada naszego rozwiązania brzmi:

```text
application identity != execution identity
```

Konto aplikacyjne odpowiada wyłącznie za zgłoszenie żądania.

Osobne konto techniczne odpowiada za wykonanie eksportu.

Aplikacja kończy swoją rolę na SQL Serverze.

Nie przechodzi dalej do SQL Agenta, SSIS ani udziału sieciowego.

---

## Nowa architektura

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
SQL Server Agent
    |
    | Credential / Proxy
    v
Dedicated execution account
    |
    v
Network share
```

W POC konto aplikacyjne to:

```text
SQLLAB\poc-ssis-app
```

A konto wykonawcze:

```text
SQLLAB\poc-ssis-export
```

To właśnie `poc-ssis-export` ma prawo zapisu do udziału sieciowego. Konto aplikacyjne tego prawa nie ma.

---

## Stage 1 – kolejka

Tabela kolejki:

```text
dbo.ExportRequest
```

Aplikacja nie wykonuje bezpośredniego `INSERT` do tej tabeli. Ma jedynie prawo `EXECUTE` do:

```text
dbo.usp_RequestExport
```

Procedura zapisuje również `ORIGINAL_LOGIN()`, więc wiemy, kto rzeczywiście zlecił eksport.

---

## Stage 2 – minimalne uprawnienia aplikacji

Konto aplikacyjne ma:

```text
EXECUTE dbo.usp_RequestExport
```

ale nie ma bezpośredniego:

```text
SELECT
INSERT
UPDATE
DELETE
```

na `dbo.ExportRequest`.

Nie ma też uprawnień do SQL Agenta, Credential, Proxy ani udziału SMB.

---

## Stage 3 – dedykowana tożsamość wykonawcza

Tworzymy osobne konto techniczne:

```text
SQLLAB\poc-ssis-export
```

Dostaje ono prawo zapisu wyłącznie do:

```text
\\DC01\SSISLab$
```

W SQL Server Agent tworzymy Credential oraz Proxy. Dzięki temu SQL Agent może uruchamiać proces jako `SQLLAB\poc-ssis-export` bez przekazywania dalej tożsamości aplikacji.

---

## Stage 4 – dowód tożsamości

Na SQL64 subsystem SSIS był widoczny, ale środowisko nie miało pełnego zestawu komponentów potrzebnych do wygodnego przygotowania pakietu `.dtsx`.

Dlatego do testu użyliśmy `CmdExec Proxy` i PowerShella:

```text
SQL Agent
  -> CmdExec Proxy
  -> SQLLAB\poc-ssis-export
  -> PowerShell
  -> SMB
```

Plik testowy pokazał:

```text
WindowsIdentity=SQLLAB\poc-ssis-export
MachineName=SQL64
```

To jest kluczowy dowód, że proces wykonawczy działa pod dedykowaną tożsamością.

---

## Stage 5 – pełny worker

Worker SQL Agenta pobiera zadania z kolejki i obsługuje stany:

```text
NEW -> PROCESSING -> DONE
        |
        +-> RETRY -> PROCESSING
        |
        +-> FAILED
```

Do bezpiecznego przejęcia rekordu używamy:

```sql
UPDLOCK, READPAST, ROWLOCK
```

oraz `WorkerToken`, aby inny worker nie zakończył zadania, którego sam nie przejął.

Domyślnie mamy trzy próby i minutę przerwy przed kolejną próbą.

---

## Co udowodnił POC

Końcowy przepływ:

```text
SQLLAB\poc-ssis-app
  -> SQL Server
  -> dbo.usp_RequestExport
  -> dbo.ExportRequest
  -> SQL Agent
  -> Proxy
  -> SQLLAB\poc-ssis-export
  -> SMB
```

Czyli mamy dwa osobne uwierzytelnienia:

```text
Application account -> SQL Server
Execution account   -> SMB share
```

Nie przekazujemy tożsamości aplikacji z SQL Servera do serwera plików, więc nie potrzebujemy `Unconstrained Delegation`.

---

## A co z SSIS?

W POC:

```text
SQL Agent -> CmdExec Proxy -> execution account -> PowerShell -> SMB
```

W produkcji możemy mieć:

```text
SQL Agent -> SSIS Proxy -> execution account -> SSIS -> SMB
```

Zmienia się executor, ale model bezpieczeństwa pozostaje ten sam.

---

## Scenariusz demo – kolejność uruchamiania skryptów

### Przygotowanie

Całym POC administrujemy ze stacji:

```text
DEWELOPER
```

Nie używamy RDP do SQL64 ani DC01.

PowerShell uruchamiamy lokalnie na DEWELOPER przez `pwsh` z poświadczeniami domenowymi używanymi do połączeń sieciowych:

```cmd
runas /netonly /user:SQLLAB\Administrator pwsh.exe
```

Visual Studio Code również uruchamiamy przez `runas /netonly`:

```cmd
runas /netonly /user:SQLLAB\Administrator "C:\Program Files\Microsoft VS Code\Code.exe"
```

Skrypty `.sql` uruchamiamy z Visual Studio Code na:

```text
sql64.sqllab.local,1433
Windows Authentication
```

Skrypty `.ps1` uruchamiamy z `pwsh` na DEWELOPER. Skrypty wymagające AD lub zasobów SQL64 wykonują zdalne operacje przez WinRM.

Architektura administracyjna:

```text
DEWELOPER -> SQL64
DEWELOPER -> DC01
```

Nie używamy łańcucha `DEWELOPER -> SQL64 -> DC01`, dzięki czemu nie wchodzimy w problem WinRM second-hop.

Katalog POC:

```text
scripts\ssis-secure-export-poc
```

Skrypt konta aplikacyjnego znajduje się katalog wyżej:

```text
scripts\poc-active-directory\Initialize-POCActiveDirectory.ps1
```

### Krok 1 – baza i kolejka

**Gdzie:** VS Code na DEWELOPER, połączenie do `sql64.sqllab.local,1433`.

Uruchamiamy kolejno:

```text
01-create-database.sql
02-create-schema.sql
03-create-request-procedure.sql
04-test-stage1.sql
```

Po tym etapie mamy bazę `SSIS_Delegation_Lab`, tabelę `dbo.ExportRequest`, procedurę `dbo.usp_RequestExport` i pierwszy test kolejki.

### Krok 2 – konto aplikacyjne w Active Directory

**Gdzie:** `pwsh` na DEWELOPER.

Przechodzimy do katalogu:

```powershell
Set-Location ..\poc-active-directory
```

Uruchamiamy:

```powershell
.\Initialize-POCActiveDirectory.ps1
```

Skrypt łączy się bezpośrednio przez WinRM z `dc01.sqllab.local`, tworzy lub weryfikuje konto:

```text
SQLLAB\poc-ssis-app
```

i ustawia:

```text
AccountNotDelegated          = True
TrustedForDelegation         = False
TrustedToAuthForDelegation   = False
```

Wracamy do katalogu POC:

```powershell
Set-Location ..\ssis-secure-export-poc
```

### Krok 3 – minimalne prawa konta aplikacyjnego

**Gdzie:** VS Code na DEWELOPER, połączenie do SQL64 jako `SQLLAB\Administrator` przez `runas /netonly`.

Uruchamiamy:

```text
05-create-application-security.sql
06-test-application-security.sql
```

Skrypt `05` używa jawnie konta:

```text
SQLLAB\poc-ssis-app
```

Skrypt `06` wykonuje test pod tą tożsamością przez:

```sql
EXECUTE AS LOGIN = N'SQLLAB\poc-ssis-app';
```

a po zakończeniu wykonuje:

```sql
REVERT;
```

Nie trzeba zamykać VS Code ani uruchamiać osobnej sesji jako konto aplikacyjne.

Oczekiwany wynik:

```text
EXECUTE dbo.usp_RequestExport = dozwolone
SELECT dbo.ExportRequest      = zabronione
INSERT dbo.ExportRequest      = zabronione
UPDATE dbo.ExportRequest      = zabronione
DELETE dbo.ExportRequest      = zabronione
```

### Krok 4 – konto wykonawcze

**Gdzie:** `pwsh` na DEWELOPER.

```powershell
.\07-create-export-account.ps1
```

Powstaje lub zostaje zweryfikowane konto:

```text
SQLLAB\poc-ssis-export
```

Skrypt wykonuje operacje AD bezpośrednio na DC01 przez WinRM.

### Krok 5 – udział SMB

**Gdzie:** `pwsh` na DEWELOPER.

```powershell
.\08-create-test-share.ps1
```

Na DC01 powstaje:

```text
C:\POC\SSISLab
\\DC01\SSISLab$
```

Prawo zapisu otrzymuje `SQLLAB\poc-ssis-export`.

### Krok 6 – test SMB

**Gdzie:** `pwsh` na DEWELOPER.

```powershell
.\09-test-share-access.ps1
```

Podajemy hasło `SQLLAB\poc-ssis-export`. Test wykonuje create/read/delete na `\\dc01.sqllab.local\SSISLab$`.

### Krok 7 – SQL Agent Credential

**Gdzie:** `pwsh` na DEWELOPER.

```powershell
.\10-create-sql-agent-credential.ps1
```

Skrypt łączy się z `sql64.sqllab.local,1433`, prosi o hasło konta wykonawczego i tworzy:

```text
POC_SSIS_Export_Credential
```

Hasło nie trafia do repozytorium.

### Krok 8 – Proxy SSIS

**Gdzie:** VS Code na DEWELOPER.

```text
11-create-ssis-proxy.sql
12-verify-stage3.sql
```

Weryfikujemy Credential, Proxy i subsystem SSIS.

### Krok 9 – CmdExec Proxy

**Gdzie:** VS Code na DEWELOPER.

```text
13-create-cmdexec-proxy.sql
```

Powstaje:

```text
POC_Export_CmdExec_Proxy
```

### Krok 10 – dowód tożsamości wykonawczej

**Gdzie:** VS Code na DEWELOPER.

```text
14-create-stage4-job.sql
15-test-stage4.sql
```

Na `\\DC01\SSISLab$` powinien pojawić się plik `cmdexec-proxy-test-*.txt` z:

```text
WindowsIdentity=SQLLAB\poc-ssis-export
MachineName=SQL64
```

### Krok 11 – rozszerzenie kolejki Stage 5

**Gdzie:** VS Code na DEWELOPER.

```text
16-upgrade-stage5-queue.sql
```

### Krok 12 – deployment workera

**Gdzie:** `pwsh` na DEWELOPER.

Nie kopiujemy pliku ręcznie na SQL64. Uruchamiamy:

```powershell
.\17-stage5-worker.ps1 -DeployToSql64
```

Skrypt używa WinRM i zapisuje worker na SQL64 jako:

```text
C:\SSIS\POC\Stage5Worker.ps1
```

Oczekiwane zakończenie:

```text
Stage5 worker deployed successfully.
```

### Krok 13 – job Stage 5

**Gdzie:** VS Code na DEWELOPER.

```text
18-create-stage5-job.sql
```

Job `POC_Secure_Export_Stage5_Worker` uruchamia `C:\SSIS\POC\Stage5Worker.ps1` przez `POC_Export_CmdExec_Proxy`.

### Krok 14 – test end-to-end

**Gdzie:** VS Code na DEWELOPER.

```text
19-test-stage5.sql
```

Oczekiwany wynik:

```text
STAGE5_END_TO_END_OK
```

W pliku wynikowym pokazujemy:

```text
WorkerIdentity=SQLLAB\poc-ssis-export
MachineName=SQL64
```

### Krok 15 – cleanup

**Gdzie:** `pwsh` na DEWELOPER.

Najpierw:

```powershell
.\20-cleanup-poc.ps1 -WhatIf
```

Po sprawdzeniu zakresu:

```powershell
.\20-cleanup-poc.ps1 -Force
```

Cleanup łączy się osobno z SQL64 i DC01, dzięki czemu nie występuje WinRM second-hop.

Końcowa weryfikacja powinna pokazać zero jobów, proxy, Credential i bazy POC oraz brak katalogu workera i udziału SMB.

---

## Skrócona ściąga do nagrania

```text
VS Code / DEWELOPER -> SQL64:
  01-create-database.sql
  02-create-schema.sql
  03-create-request-procedure.sql
  04-test-stage1.sql

pwsh / DEWELOPER -> DC01:
  ..\poc-active-directory\Initialize-POCActiveDirectory.ps1

VS Code / DEWELOPER -> SQL64:
  05-create-application-security.sql
  06-test-application-security.sql

pwsh / DEWELOPER:
  07-create-export-account.ps1
  08-create-test-share.ps1
  09-test-share-access.ps1
  10-create-sql-agent-credential.ps1

VS Code / DEWELOPER -> SQL64:
  11-create-ssis-proxy.sql
  12-verify-stage3.sql
  13-create-cmdexec-proxy.sql
  14-create-stage4-job.sql
  15-test-stage4.sql
  16-upgrade-stage5-queue.sql

pwsh / DEWELOPER -> SQL64:
  17-stage5-worker.ps1 -DeployToSql64

VS Code / DEWELOPER -> SQL64:
  18-create-stage5-job.sql
  19-test-stage5.sql

pwsh / DEWELOPER:
  20-cleanup-poc.ps1 -WhatIf
  20-cleanup-poc.ps1 -Force
```

---

## Zakończenie

Jeżeli macie architekturę, w której aplikacja łączy się do SQL Servera, a później SQL Server albo SSIS musi dostać się do kolejnego zasobu sieciowego, to zanim zaczniecie konfigurować delegację, zadajcie sobie jedno pytanie:

**czy naprawdę potrzebujemy przenosić tożsamość użytkownika dalej?**

Bardzo często odpowiedź brzmi: nie.

Wtedy prostszy i bezpieczniejszy wzorzec to:

```text
submit request
-> persist queue
-> execute asynchronously under dedicated identity
```

W naszym POC działa to od początku do końca bez `Unconstrained Delegation`, a cała administracja odbywa się z DEWELOPER bez RDP.
