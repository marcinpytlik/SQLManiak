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
