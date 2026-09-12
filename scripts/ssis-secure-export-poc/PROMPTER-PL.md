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

Schemat wygląda tak:

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

W naszym POC konto aplikacyjne to:

```text
SQLLAB\poc-ssis-app
```

A konto wykonawcze:

```text
SQLLAB\poc-ssis-export
```

I to właśnie konto `poc-ssis-export` ma prawo zapisu do udziału sieciowego.

Konto aplikacyjne tego prawa nie ma.

---

## Stage 1 – kolejka

Zaczęliśmy od prostej kolejki w SQL Serverze.

Tabela nazywa się:

```text
dbo.ExportRequest
```

Aplikacja nie robi bezpośrednio `INSERT` do tej tabeli.

Ma jedynie prawo `EXECUTE` do:

```text
dbo.usp_RequestExport
```

Procedura przyjmuje parametry biznesowe, na przykład `CustomerId` i `ReportDate`.

Dodatkowo zapisujemy:

```sql
ORIGINAL_LOGIN()
```

czyli wiemy, kto faktycznie zlecił eksport.

---

## Stage 2 – minimalne uprawnienia aplikacji

Następnie ograniczyliśmy konto aplikacyjne.

Ma ono:

```text
EXECUTE dbo.usp_RequestExport
```

ale nie ma:

```text
SELECT
INSERT
UPDATE
DELETE
```

na tabeli kolejki.

Nie ma również uprawnień do SQL Agenta, Credential, Proxy ani udziału sieciowego.

To jest bardzo ważne.

Aplikacja zgłasza zadanie biznesowe.

Nie steruje mechanizmem wykonawczym.

---

## Stage 3 – dedykowana tożsamość wykonawcza

Następnie utworzyliśmy osobne konto techniczne:

```text
SQLLAB\poc-ssis-export
```

To konto otrzymało prawo zapisu do konkretnego udziału:

```text
\\DC01\SSISLab$
```

W SQL Server Agent utworzyliśmy Credential oraz Proxy.

Dzięki temu SQL Agent może uruchomić krok joba właśnie jako:

```text
SQLLAB\poc-ssis-export
```

I nie potrzebujemy przekazywać dalej tożsamości aplikacji.

---

## Stage 4 – dowód tożsamości

Tu pojawiła się ciekawa rzecz.

Na naszym serwerze SQL64 subsystem SSIS był widoczny, ale środowisko nie miało pełnego zestawu komponentów potrzebnych do wygodnego przygotowania pakietu SSIS.

Nie było między innymi:

```text
Microsoft.SqlServer.ManagedDTS.dll
```

Nie chcieliśmy instalować dodatkowych komponentów tylko po to, żeby udowodnić model bezpieczeństwa.

Dlatego do testu użyliśmy `CmdExec Proxy` i PowerShella.

Schemat był taki:

```text
SQL Agent
  -> CmdExec Proxy
  -> SQLLAB\poc-ssis-export
  -> PowerShell
  -> SMB
```

PowerShell zapisał do pliku aktualną tożsamość procesu.

I dostaliśmy:

```text
WindowsIdentity=SQLLAB\poc-ssis-export
```

To był kluczowy moment POC.

SQL Agent rzeczywiście uruchomił proces pod dedykowanym kontem technicznym.

---

## Stage 5 – pełny worker

Na końcu spięliśmy wszystko razem.

Aplikacja dodaje rekord `NEW`.

Worker SQL Agenta pobiera zadanie i przełącza status na `PROCESSING`.

Po sukcesie mamy:

```text
DONE
```

W przypadku błędu:

```text
RETRY
```

lub po wyczerpaniu prób:

```text
FAILED
```

Pełny cykl wygląda tak:

```text
NEW -> PROCESSING -> DONE
        |
        +-> RETRY -> PROCESSING
        |
        +-> FAILED
```

Do przejęcia zadania używamy:

```sql
UPDLOCK, READPAST, ROWLOCK
```

oraz `WorkerToken`, żeby inny worker nie zakończył rekordu, którego sam nie przejął.

Domyślnie ustawiliśmy trzy próby i minutę przerwy przed ponowieniem.

---

## Co udowodnił POC

Ostateczny przepływ wygląda tak:

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

Nie przekazujemy tożsamości aplikacji z SQL Servera do serwera plików.

A skoro nie przekazujemy jej dalej, to nie potrzebujemy `Unconstrained Delegation`.

---

## A co z SSIS?

W środowisku docelowym możemy użyć SSIS.

Zmienia się executor, ale nie zmienia się model bezpieczeństwa.

W POC mamy:

```text
SQL Agent -> CmdExec Proxy -> execution account -> PowerShell -> SMB
```

W produkcji możemy mieć:

```text
SQL Agent -> SSIS Proxy -> execution account -> SSIS -> SMB
```

Najważniejsze jest to, że konto aplikacyjne nadal kończy swoją rolę na SQL Serverze.

---

## Dlaczego ten model jest bezpieczniejszy

Po pierwsze — zasada najmniejszych uprawnień.

Konto aplikacyjne nie ma dostępu do udziału sieciowego.

Po drugie — separacja odpowiedzialności.

Aplikacja zleca zadanie, a infrastruktura wykonuje je pod kontrolowaną tożsamością.

Po trzecie — nie przekazujemy ścieżki UNC z aplikacji.

Miejsce docelowe jest zdefiniowane po stronie serwera.

Po czwarte — mamy kolejkę, retry, audyt i kontrolę statusu.

I po piąte — eliminujemy potrzebę używania `Unconstrained Delegation`.

---

## Jedna ważna uwaga

Jeżeli wymaganiem biznesowym byłoby zachowanie oryginalnej tożsamości użytkownika aż do udziału sieciowego, wtedy temat KCD albo RBCD nadal byłby aktualny.

Ale w naszym przypadku nie było takiego wymagania.

Potrzebowaliśmy wykonać eksport.

Nie potrzebowaliśmy, żeby serwer plików widział konto aplikacyjne jako użytkownika wykonującego zapis.

To rozróżnienie jest kluczowe.

---

## Scenariusz demo – kolejność uruchamiania skryptów

Poniższa część jest przeznaczona bezpośrednio do nagrania. Pokazuje dokładnie **co uruchomić, gdzie i w jakiej kolejności**.

### Przygotowanie

Repozytorium klonujemy lub aktualizujemy na stacji administracyjnej albo bezpośrednio na `SQL64`.

Katalog roboczy:

```text
scripts\ssis-secure-export-poc
```

W POC używamy trzech maszyn logicznych:

```text
SQL64  - SQL Server + SQL Server Agent
DC01   - Active Directory + udział SMB
stacja administracyjna - PowerShell / SSMS; może to być również SQL64
```

### Krok 1 – baza i kolejka

**Gdzie:** połączenie SSMS do `SQL64`.

Uruchamiamy kolejno:

```text
01-create-database.sql
02-create-schema.sql
03-create-request-procedure.sql
04-test-stage1.sql
```

Po tym etapie mamy bazę `SSIS_Delegation_Lab`, tabelę `dbo.ExportRequest`, procedurę `dbo.usp_RequestExport` i pierwszy test kolejki.

### Krok 2 – konto aplikacyjne i minimalne prawa

**Gdzie:** SSMS połączony z `SQL64`.

Uruchamiamy:

```text
05-create-application-security.sql
06-test-application-security.sql
```

Oczekiwany rezultat: konto `SQLLAB\poc-ssis-app` może wykonać `dbo.usp_RequestExport`, ale nie ma bezpośredniego CRUD do `dbo.ExportRequest`.

> Konto domenowe `poc-ssis-app` musi wcześniej istnieć w Active Directory. Jeżeli budujemy POC od zera, konto aplikacyjne tworzymy przez skrypt `Initialize-POCActiveDirectory.ps1` z katalogu `scripts\poc-active-directory` uruchomiony na `DC01` lub ze stacji z modułem ActiveDirectory i uprawnieniami domenowymi.

### Krok 3 – konto wykonawcze

**Gdzie:** PowerShell uruchomiony z uprawnieniami domenowymi; najprościej na `DC01`.

Uruchamiamy:

```powershell
.\07-create-export-account.ps1
```

Powstaje konto:

```text
SQLLAB\poc-ssis-export
```

Nie ustawiamy dla niego `Unconstrained Delegation`.

### Krok 4 – udział SMB

**Gdzie:** `DC01`, PowerShell jako administrator.

Uruchamiamy:

```powershell
.\08-create-test-share.ps1
```

Powstaje:

```text
C:\POC\SSISLab
\\DC01\SSISLab$
```

Prawo zapisu otrzymuje konto `SQLLAB\poc-ssis-export`.

### Krok 5 – test dostępu do udziału

**Gdzie:** stacja administracyjna albo `SQL64`, PowerShell.

Uruchamiamy:

```powershell
.\09-test-share-access.ps1
```

Test uwierzytelnia się bezpośrednio kontem wykonawczym i sprawdza utworzenie, odczyt oraz usunięcie pliku na `\\DC01\SSISLab$`.

### Krok 6 – Credential SQL Server Agent

**Gdzie:** najlepiej `SQL64`, PowerShell z uprawnieniami administracyjnymi do SQL Servera.

Uruchamiamy:

```powershell
.\10-create-sql-agent-credential.ps1
```

Skrypt poprosi o hasło konta `SQLLAB\poc-ssis-export` i utworzy:

```text
POC_SSIS_Export_Credential
```

Hasło nie trafia do repozytorium.

### Krok 7 – Proxy SSIS i weryfikacja Stage 3

**Gdzie:** SSMS połączony z `SQL64`.

Uruchamiamy:

```text
11-create-ssis-proxy.sql
12-verify-stage3.sql
```

W tym miejscu potwierdzamy Credential, Proxy i mapowanie do subsystemu SQL Server Agent.

### Krok 8 – CmdExec Proxy

Ponieważ na naszym `SQL64` nie było pełnych komponentów potrzebnych do wygodnego zbudowania pakietu `.dtsx`, dalszy POC realizujemy przez CmdExec.

**Gdzie:** SSMS połączony z `SQL64`.

Uruchamiamy:

```text
13-create-cmdexec-proxy.sql
```

Powstaje:

```text
POC_Export_CmdExec_Proxy
```

korzystający z tego samego Credential i tego samego konta `SQLLAB\poc-ssis-export`.

### Krok 9 – dowód tożsamości wykonawczej

**Gdzie:** SSMS połączony z `SQL64`.

Uruchamiamy:

```text
14-create-stage4-job.sql
15-test-stage4.sql
```

Po sukcesie na `\\DC01\SSISLab$` pojawia się plik `cmdexec-proxy-test-*.txt`.

Otwieramy go i pokazujemy:

```text
WindowsIdentity=SQLLAB\poc-ssis-export
MachineName=SQL64
```

To jest najważniejszy dowód techniczny w Stage 4.

### Krok 10 – rozszerzenie kolejki do pełnego workera

**Gdzie:** SSMS połączony z `SQL64`.

Uruchamiamy:

```text
16-upgrade-stage5-queue.sql
```

Skrypt dodaje mechanizm retry, `WorkerToken` i wewnętrzne procedury workera.

### Krok 11 – skrypt workera

Plik:

```text
17-stage5-worker.ps1
```

nie jest uruchamiany ręcznie jako główny test. Najpierw kopiujemy go na `SQL64`.

**Gdzie:** `SQL64`, PowerShell jako administrator.

```powershell
New-Item -ItemType Directory -Path 'C:\SSIS\POC' -Force

Copy-Item `
  '.\17-stage5-worker.ps1' `
  'C:\SSIS\POC\Stage5Worker.ps1' `
  -Force

Test-Path 'C:\SSIS\POC\Stage5Worker.ps1'
```

Oczekiwane:

```text
True
```

### Krok 12 – job Stage 5

**Gdzie:** SSMS połączony z `SQL64`.

Uruchamiamy:

```text
18-create-stage5-job.sql
```

Job:

```text
POC_Secure_Export_Stage5_Worker
```

uruchamia:

```text
C:\SSIS\POC\Stage5Worker.ps1
```

przez `POC_Export_CmdExec_Proxy`.

### Krok 13 – test end-to-end

**Gdzie:** SSMS połączony z `SQL64`.

Uruchamiamy:

```text
19-test-stage5.sql
```

Test tworzy żądania w kolejce i czeka na ich przetworzenie.

Oczekiwany rezultat:

```text
STAGE5_END_TO_END_OK
```

Następnie pokazujemy rekordy w `dbo.ExportRequest` oraz pliki utworzone na:

```text
\\DC01\SSISLab$
```

W pliku wynikowym ponownie pokazujemy:

```text
WorkerIdentity=SQLLAB\poc-ssis-export
MachineName=SQL64
```

### Krok 14 – cleanup po nagraniu

Po nagraniu możemy usunąć całe środowisko POC.

**Gdzie:** stacja administracyjna z dostępem PowerShell Remoting do `SQL64` i `DC01`, `Invoke-Sqlcmd` oraz uprawnieniami do SQL Servera i Active Directory.

Najpierw wykonujemy tylko symulację:

```powershell
.\20-cleanup-poc.ps1 -WhatIf
```

Dopiero po sprawdzeniu zakresu:

```powershell
.\20-cleanup-poc.ps1
```

Skrypt poprosi o wpisanie:

```text
DELETE-POC
```

Można zachować wybrane elementy:

```text
-KeepAdAccounts
-KeepShare
-KeepLocalFiles
-KeepDatabase
```

### Skrócona ściąga do nagrania

```text
DC01 / AD:
  Initialize-POCActiveDirectory.ps1
  07-create-export-account.ps1
  08-create-test-share.ps1

SQL64 / SSMS:
  01-create-database.sql
  02-create-schema.sql
  03-create-request-procedure.sql
  04-test-stage1.sql
  05-create-application-security.sql
  06-test-application-security.sql

PowerShell:
  09-test-share-access.ps1
  10-create-sql-agent-credential.ps1

SQL64 / SSMS:
  11-create-ssis-proxy.sql
  12-verify-stage3.sql
  13-create-cmdexec-proxy.sql
  14-create-stage4-job.sql
  15-test-stage4.sql
  16-upgrade-stage5-queue.sql

SQL64 / PowerShell:
  copy 17-stage5-worker.ps1 -> C:\SSIS\POC\Stage5Worker.ps1

SQL64 / SSMS:
  18-create-stage5-job.sql
  19-test-stage5.sql

Po nagraniu / PowerShell:
  20-cleanup-poc.ps1 -WhatIf
  20-cleanup-poc.ps1
```

---

## Zakończenie

Jeżeli więc macie architekturę, w której aplikacja łączy się do SQL Servera, a później SQL Server albo SSIS musi dostać się do kolejnego zasobu sieciowego, to zanim zaczniecie konfigurować delegację, zadajcie sobie jedno pytanie:

**czy naprawdę potrzebujemy przenosić tożsamość użytkownika dalej?**

Bardzo często odpowiedź brzmi: nie.

I wtedy prostszy oraz bezpieczniejszy wzorzec to:

```text
submit request
-> persist queue
-> execute asynchronously under dedicated identity
```

W naszym POC zadziałało to od początku do końca.

Bez `Unconstrained Delegation`.

Repozytorium ze wszystkimi skryptami oraz ADR-em znajdziecie w opisie materiału.
