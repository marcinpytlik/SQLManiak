# ADR-001: Bezpieczny eksport bez Unconstrained Delegation

- **Status:** Zaakceptowano
- **Data:** 2026-09-12
- **Zakres:** aplikacja Windows -> SQL Server -> eksport w tle -> udział SMB
- **Repozytorium POC:** `scripts/ssis-secure-export-poc`

## 1. Kontekst

Aplikacja Windows łączy się z SQL Serverem przy użyciu Windows Authentication i zleca wygenerowanie eksportu. Wynik eksportu musi zostać zapisany na udziale sieciowym.

Pierwotna architektura opierała się na przekazywaniu tożsamości aplikacji dalej niż SQL Server. W praktyce prowadzi to do klasycznego problemu Windows double-hop i presji na włączenie `Unconstrained Delegation` dla konta aplikacyjnego.

Takie podejście ma dwa podstawowe problemy:

1. tożsamość aplikacji zaczyna mieć znaczenie również poza granicą bezpieczeństwa SQL Servera,
2. kompromitacja szeroko delegowanej tożsamości zwiększa potencjalny zakres skutków incydentu.

Celem POC nie było więc poprawne skonfigurowanie delegacji, ale całkowite usunięcie potrzeby jej stosowania.

## 2. Decyzja

Odpowiedzialność konta aplikacyjnego kończy się na SQL Serverze.

Aplikacja może jedynie zgłosić żądanie biznesowe przez procedurę składowaną. SQL Server zapisuje to żądanie do kolejki. Następnie SQL Server Agent przetwarza żądanie w tle pod osobną tożsamością techniczną reprezentowaną przez SQL Agent Credential i Proxy.

Dostęp do udziału SMB otrzymuje konto wykonawcze, a nie konto aplikacyjne.

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
SQL Server Agent worker
    |
    | Credential / Proxy
    v
Dedicated execution account
    |
    | CmdExec w POC
    | SSIS w środowisku docelowym
    v
Network share
```

Kluczowa zasada architektoniczna brzmi:

```text
application identity != execution identity
```

## 3. Model tożsamości

### Konto aplikacyjne

Konto POC:

```text
SQLLAB\poc-ssis-app
```

Odpowiedzialność:

- uwierzytelnienie do SQL Servera,
- wykonanie `dbo.usp_RequestExport`,
- przekazanie parametrów biznesowych, np. `CustomerId` i `ReportDate`.

Konto aplikacyjne **nie otrzymuje**:

- bezpośrednich praw CRUD do `dbo.ExportRequest`,
- uprawnień operatorskich do SQL Agenta,
- dostępu do obiektów Credential i Proxy,
- dostępu do udziału SMB,
- uprawnień do wykonywania SSIS,
- `Unconstrained Delegation`.

Oryginalny zlecający jest zapisywany przez `ORIGINAL_LOGIN()` na potrzeby audytu.

### Konto wykonawcze

Konto POC:

```text
SQLLAB\poc-ssis-export
```

Odpowiedzialność:

- uruchamianie workera przez SQL Server Agent Proxy,
- dostęp wyłącznie do wewnętrznego interfejsu workera w SQL Serverze,
- tworzenie plików na docelowym udziale SMB.

Konto wykonawcze otrzymuje tylko te uprawnienia, które są niezbędne do realizacji eksportu.

## 4. Model kolejki

Aplikacja dodaje żądania pośrednio przez:

```text
dbo.usp_RequestExport
```

Żądania są zapisywane w:

```text
dbo.ExportRequest
```

Cykl przetwarzania:

```text
NEW -> PROCESSING -> DONE
        |
        +-> RETRY -> PROCESSING
        |
        +-> FAILED
```

POC dodaje między innymi:

- licznik prób,
- maksymalną liczbę prób,
- czas następnej próby,
- token workera,
- znaczniki czasu przetwarzania,
- ścieżkę pliku wynikowego,
- komunikat błędu.

## 5. Model współbieżności

Worker atomowo przejmuje jedno żądanie przy użyciu blokad:

```sql
UPDLOCK, READPAST, ROWLOCK
```

Pozwala to wielu workerom konkurować o dostępne zadania bez typowego ryzyka podwójnego przejęcia tego samego rekordu.

W momencie przejęcia generowany jest `WorkerToken`. Operacja zakończenia sukcesem lub błędem musi przedstawić ten sam token. Chroni to przed zakończeniem zadania przez inny worker niż ten, który je przejął.

Parametry POC:

```text
MaxAttempts = 3
RetryDelay  = 60 sekund
MaxItems    = 10 na jedno uruchomienie workera
Schedule    = co 1 minutę
```

Są to wartości operacyjne, a nie wymagania architektoniczne.

## 6. Idempotencja i ryzyko duplikacji plików

Worker używa deterministycznej nazwy pliku opartej o `RequestId`.

Zmniejsza to ryzyko powstania duplikatów w scenariuszu, w którym proces zapisze plik, ale zakończy się błędem przed aktualizacją rekordu kolejki.

W środowisku produkcyjnym należy dodatkowo jednoznacznie zdefiniować politykę nadpisywania, wersjonowania i retencji plików.

## 7. Ścieżka wykonawcza POC

Ostateczna ścieżka POC:

```text
SQLLAB\poc-ssis-app
  -> dbo.usp_RequestExport
  -> dbo.ExportRequest
  -> SQL Agent Stage 5 Worker
  -> POC_Export_CmdExec_Proxy
  -> SQLLAB\poc-ssis-export
  -> PowerShell
  -> \\DC01\SSISLab$
```

Plik wynikowy zapisuje tożsamość procesu wykonawczego. Test potwierdził:

```text
WindowsIdentity=SQLLAB\poc-ssis-export
```

Oznacza to, że tożsamość aplikacji nie jest przekazywana do serwera plików.

## 8. Dlaczego w POC użyto CmdExec

Docelowa architektura zakłada możliwość użycia SSIS jako executora.

Na serwerze POC `SQL64`:

- SQL Agent posiada subsystem `SSIS`,
- SQL Agent poprawnie uruchomił krok SSIS przez dedykowane Proxy,
- historia joba potwierdziła wykonanie jako `SQLLAB\poc-ssis-export`,
- serwer nie posiada jednak `Microsoft.SqlServer.ManagedDTS.dll`,
- nie ma zainstalowanego SSDT / Visual Studio,
- w tym labie nie używamy SSISDB.

Nie instalowaliśmy dodatkowych komponentów wyłącznie po to, aby utworzyć jednorazowy pakiet testowy.

Dlatego Stage 4 i Stage 5 używają `CmdExec` z PowerShellem. Nie zmienia to decyzji architektonicznej dotyczącej separacji tożsamości.

Na środowisku produkcyjnym z pełnym runtime SSIS executor może zostać zastąpiony:

```text
POC:
SQL Agent -> CmdExec Proxy -> konto wykonawcze -> PowerShell -> SMB

Produkcja:
SQL Agent -> SSIS Proxy -> konto wykonawcze -> SSIS package -> SMB
```

Granica bezpieczeństwa pozostaje bez zmian.

## 9. Dlaczego Unconstrained Delegation nie jest potrzebne

Architektura nie próbuje przekazywać tożsamości Kerberos uwierzytelnionego konta aplikacyjnego z SQL Servera do serwera plików.

Zamiast tego występują dwa niezależne uwierzytelnienia:

```text
Application account -> SQL Server
Execution account   -> SMB share
```

SQL Server Agent uzyskuje tożsamość wykonawczą z konfiguracji Credential/Proxy. Worker uzyskuje dostęp do SMB przy użyciu własnych poświadczeń konta wykonawczego.

Ponieważ oryginalna tożsamość wywołującego nie jest przekazywana do SMB, `Unconstrained Delegation` nie jest potrzebne dla konta aplikacyjnego.

KCD lub RBCD miałoby znaczenie dopiero wtedy, gdy przyszłe wymaganie biznesowe wymagałoby zachowania oryginalnej tożsamości użytkownika na zasobie docelowym.

## 10. Właściwości bezpieczeństwa

Zaakceptowana architektura zapewnia:

- zasadę najmniejszych uprawnień dla konta aplikacyjnego,
- brak dostępu aplikacji do SMB,
- brak bezpośredniego sterowania SQL Agentem przez aplikację,
- brak możliwości przekazania dowolnej ścieżki UNC przez użytkownika,
- brak sekretów w skryptach repozytorium,
- oddzielną tożsamość wykonawczą,
- audyt oryginalnego zlecającego,
- kontrolowany retry,
- izolację pomiędzy zgłoszeniem żądania a jego wykonaniem,
- brak potrzeby używania `Unconstrained Delegation`.

## 11. Uprawnienia udziału

Tylko dedykowane konto wykonawcze potrzebuje prawa zapisu do miejsca eksportu.

W POC miejscem docelowym jest:

```text
\\DC01\SSISLab$
```

Konto wykonawcze otrzymuje wyłącznie wymagane prawa Share i NTFS. Konto aplikacyjne jest celowo wykluczone.

W produkcji obowiązuje ta sama zasada: konto techniczne powinno mieć dostęp tylko do konkretnego, przeznaczonego dla niego miejsca eksportu.

## 12. Konsekwencje

### Pozytywne

- usunięcie potrzeby delegowania konta aplikacyjnego,
- ograniczenie blast radius,
- jawny, usługowy model dostępu do zasobów downstream,
- separacja bezpieczeństwa aplikacji od bezpieczeństwa wykonania batchowego,
- możliwość retry i przetwarzania asynchronicznego,
- widoczne błędy i statusy w kolejce,
- możliwość zmiany technologii executora bez zmiany kontraktu aplikacji.

### Koszty i kompromisy

- przetwarzanie jest asynchroniczne,
- SQL Agent staje się elementem ścieżki wykonawczej,
- kolejka i polityka retry wymagają monitoringu,
- stare rekordy `PROCESSING` wymagają polityki odzyskiwania,
- poświadczenia konta wykonawczego wymagają zarządzania cyklem życia,
- produkcyjny SSIS nadal wymaga własnego modelu wdrażania i runtime.

## 13. Rekomendacje produkcyjne

Przed wdrożeniem produkcyjnym:

1. Jeśli to możliwe, uruchamiać worker pod zarządzaną tożsamością usługową, np. gMSA, zamiast zwykłego konta domenowego z hasłem.
2. Jeżeli pozostaje klasyczne konto domenowe, zdefiniować rotację hasła i Credential.
3. Monitorować `FAILED`, nadmierną liczbę prób oraz stare rekordy `PROCESSING`.
4. Zdefiniować recovery dla workera, który zakończy się po przejęciu zadania, ale przed jego zakończeniem.
5. Utrzymywać ścieżkę eksportu po stronie serwera; aplikacja nie powinna przekazywać dowolnych UNC.
6. Osobno zweryfikować uprawnienia Share i NTFS.
7. Zdefiniować retencję plików wynikowych oraz historii kolejki.
8. Jeżeli w produkcji używany jest SSIS, wdrażać pakiety zgodnie ze wspieranym modelem organizacji i przydzielać tylko wymagane prawa do Proxy/subsystemu.
9. Przetestować zachowanie przy failover, jeżeli SQL Agent działa w środowisku FCI/HA.
10. Udokumentować właściciela rozwiązania, odpowiedzialność operacyjną i procedurę awaryjną.

## 14. Odrzucone alternatywy

### Unconstrained Delegation

Odrzucone, ponieważ rozszerza zaufanie bardziej, niż wymaga tego potrzeba biznesowa, i niepotrzebnie zwiększa ekspozycję konta aplikacyjnego.

### Bezpośredni dostęp aplikacji do SMB

Odrzucony, ponieważ wiąże aplikację z uprawnieniami udziału, zarządzaniem ścieżkami oraz downstream authentication.

### Bezpośrednie uruchamianie SQL Agent przez aplikację

Odrzucone, ponieważ aplikacja powinna zgłaszać żądania biznesowe, a nie sterować obiektami infrastrukturalnymi odpowiedzialnymi za harmonogram i wykonanie.

### Dowolny UNC przekazywany przez wywołującego

Odrzucony, ponieważ pozwalałby użytkownikowi wpływać na downstream security boundary i tworzyłby niepotrzebne ryzyko błędnej konfiguracji lub eksfiltracji danych.

## 15. Dowody walidacyjne

POC pomyślnie przeszedł następujące etapy:

```text
Stage 1  Kolejka i procedura zgłoszeniowa
Stage 2  Ograniczone uprawnienia konta aplikacyjnego
Stage 3  Dedykowane konto eksportowe, Credential, Proxy i dostęp SMB
Stage 4  Wykonanie SQL Agent Proxy jako SQLLAB\poc-ssis-export
Stage 5  Pełny worker kolejki z retry i kontrolą współbieżności
```

Kluczowa obserwacja z historii SQL Agenta i wygenerowanych plików:

```text
SQLLAB\poc-ssis-export
```

było rzeczywistą tożsamością wykonawczą, a nie konto aplikacyjne.

## 16. Architektura końcowa

```text
+---------------------------+
| Windows Application       |
| SQLLAB\poc-ssis-app       |
+-------------+-------------+
              |
              | Windows Authentication
              | EXEC dbo.usp_RequestExport
              v
+---------------------------+
| SQL Server                |
| SSIS_Delegation_Lab       |
| dbo.ExportRequest         |
+-------------+-------------+
              |
              | asynchronous dequeue
              v
+---------------------------+
| SQL Server Agent          |
| Stage 5 Worker            |
+-------------+-------------+
              |
              | Credential / Proxy
              v
+---------------------------+
| SQLLAB\poc-ssis-export    |
| dedicated execution acct  |
+-------------+-------------+
              |
              | authenticated SMB access
              v
+---------------------------+
| Network Share             |
| \\DC01\SSISLab$          |
+---------------------------+
```

## 17. Podsumowanie decyzji

POC wykazał, że wymagany proces eksportu można zrealizować bez przekazywania tożsamości konta aplikacyjnego do zasobów downstream.

Zaakceptowany wzorzec brzmi:

```text
submit request -> persist queue -> execute asynchronously under a dedicated identity
```

`Unconstrained Delegation` nie jest elementem docelowej architektury.
