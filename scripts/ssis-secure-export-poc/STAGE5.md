# Stage 5 - end-to-end queue worker

Cel tego etapu: zamknąć POC pełnym przepływem od `dbo.usp_RequestExport` do pliku na `\\DC01\SSISLab$`, z osobną tożsamością wykonawczą, retry i bez `Unconstrained Delegation`.

## Przepływ

```text
SQLLAB\poc-ssis-app
        |
        | EXEC dbo.usp_RequestExport
        v
SSIS_Delegation_Lab.dbo.ExportRequest
        |
        | SQL Agent schedule (co 1 min)
        v
POC_Secure_Export_Stage5_Worker
        |
        | CmdExec Proxy
        v
SQLLAB\poc-ssis-export
        |
        | Windows Integrated Security do SQL
        | + SMB jako własna tożsamość
        v
Stage5Worker.ps1
        |
        +--> atomowy claim kolejki
        +--> zapis pliku
        +--> DONE albo RETRY / FAILED
        v
\\DC01\SSISLab$
```

## Statusy kolejki

Stage 1 miał statusy `NEW`, `PROCESSING`, `DONE`, `FAILED`. Stage 5 rozszerza je o `RETRY` i zachowuje istniejące nazwy, żeby nie migrować bez potrzeby całego POC.

```text
NEW
  |
  v
PROCESSING
  |\
  | \ błąd i zostały próby
  |  v
  | RETRY --(NextAttemptAt)--> PROCESSING
  |
  +--> DONE
  |
  +--> FAILED   (po wykorzystaniu MaxAttempts)
```

Domyślnie `MaxAttempts = 3`, a retry następuje po 60 sekundach.

## 1. Rozszerz kolejkę i utwórz procedury workera

Uruchom jako administrator SQL Server:

```text
16-upgrade-stage5-queue.sql
```

Skrypt dodaje do `dbo.ExportRequest`:

- `AttemptCount`,
- `MaxAttempts`,
- `LastAttemptAt`,
- `NextAttemptAt`,
- `WorkerToken`.

Tworzy też procedury:

- `dbo.usp_ClaimExportRequest`,
- `dbo.usp_CompleteExportRequest`,
- `dbo.usp_FailExportRequest`.

`usp_ClaimExportRequest` używa `UPDLOCK`, `READPAST`, `ROWLOCK`, dzięki czemu dwa workery nie powinny przejąć tego samego rekordu.

Konto `SQLLAB\poc-ssis-export` dostaje `EXECUTE` tylko do tych procedur i jawny `DENY` bezpośredniego CRUD na `dbo.ExportRequest`.

## 2. Skopiuj worker na SQL64

Po merge/pull skopiuj:

```powershell
Copy-Item `
  '.\scripts\ssis-secure-export-poc\17-stage5-worker.ps1' `
  'C:\SSIS\POC\Stage5Worker.ps1' `
  -Force
```

Sprawdź:

```powershell
Test-Path 'C:\SSIS\POC\Stage5Worker.ps1'
```

Oczekiwane:

```text
True
```

Worker nie zawiera haseł. Łączy się do SQL przez `Integrated Security=SSPI`, więc z joba działa jako `SQLLAB\poc-ssis-export`.

## 3. Utwórz job workera

Uruchom:

```text
18-create-stage5-job.sql
```

Job:

- nazywa się `POC_Secure_Export_Stage5_Worker`,
- używa `POC_Export_CmdExec_Proxy`,
- uruchamia `C:\SSIS\POC\Stage5Worker.ps1`,
- przetwarza maks. 10 rekordów na uruchomienie,
- ma harmonogram co 1 minutę.

## 4. Test end-to-end

Uruchom:

```text
19-test-stage5.sql
```

Test tworzy dwa żądania (`CustomerId` 5001 i 5002), uruchamia job jeżeli nie działa już z harmonogramu i czeka maksymalnie 120 sekund.

Oczekiwany wynik:

```text
Status = DONE
AttemptCount = 1
ErrorMessage = NULL
WorkerToken = NULL
```

Na `\\DC01\SSISLab$` powinny pojawić się dwa pliki o deterministycznych nazwach:

```text
export-<RequestId>-customer-5001-<yyyymmdd>.txt
export-<RequestId>-customer-5002-<yyyymmdd>.txt
```

W środku każdego pliku powinno być m.in.:

```text
WorkerIdentity=SQLLAB\poc-ssis-export
MachineName=SQL64
```

Na końcu `19-test-stage5.sql` powinien zwrócić:

```text
STAGE5_END_TO_END_OK
```

# Jak działa worker - szczegółowo

## Rola workera

Worker jest konsumentem kolejki. Nie przyjmuje żądania bezpośrednio od aplikacji. Jego jedynym zadaniem jest okresowo sprawdzić, czy w `dbo.ExportRequest` istnieje rekord gotowy do wykonania, bezpiecznie go przejąć, wykonać eksport i zapisać wynik.

Dzięki temu oddzielamy dwa etapy:

```text
REQUEST   -> aplikacja zgłasza żądanie
EXECUTION -> worker wykonuje eksport
```

Aplikacja kończy swoją rolę po utworzeniu rekordu `NEW`. Błąd udziału SMB albo chwilowa awaria eksportu nie musi więc oznaczać błędu po stronie aplikacji. Takie zdarzenie może zostać obsłużone przez retry.

## Tożsamość procesu

SQL Server Agent uruchamia `Stage5Worker.ps1` przez `POC_Export_CmdExec_Proxy`. Proxy korzysta z Credential powiązanego z kontem:

```text
SQLLAB\poc-ssis-export
```

Worker łączy się z SQL Server przez:

```text
Integrated Security=SSPI
```

Nie przechowuje loginu ani hasła w skrypcie. Połączenie do SQL odbywa się jako bieżąca tożsamość procesu, czyli `SQLLAB\poc-ssis-export`.

To samo konto uwierzytelnia się bezpośrednio do `\\DC01\SSISLab$`.

## Worker nie ma bezpośredniego dostępu do kolejki

Konto wykonawcze ma tylko:

```text
EXECUTE dbo.usp_ClaimExportRequest
EXECUTE dbo.usp_CompleteExportRequest
EXECUTE dbo.usp_FailExportRequest
```

Jednocześnie ma jawny `DENY` na:

```text
SELECT
INSERT
UPDATE
DELETE
```

wobec `dbo.ExportRequest`.

Dzięki temu worker nie może dowolnie modyfikować statusów ani danych kolejki. Każda zmiana stanu musi przejść przez kontrolowane procedury.

## Claim - atomowe przejęcie zadania

Przed każdym pobraniem worker generuje nowy GUID:

```powershell
$workerToken = [Guid]::NewGuid()
```

Następnie wywołuje:

```text
dbo.usp_ClaimExportRequest
```

Procedura szuka jednego rekordu spełniającego warunki:

```text
Status = NEW lub RETRY
AttemptCount < MaxAttempts
NextAttemptAt jest NULL lub <= bieżący czas
```

Wybór i przejęcie rekordu są wykonywane w jednej transakcji.

Do wyboru wykorzystywane są:

```sql
UPDLOCK, READPAST, ROWLOCK
```

Znaczenie:

- `UPDLOCK` - rekord wybrany do przejęcia otrzymuje blokadę aktualizacyjną,
- `READPAST` - drugi worker pomija rekord już zablokowany i może pobrać następny,
- `ROWLOCK` - preferowana jest blokada na poziomie wiersza, co ułatwia równoległe przetwarzanie kolejki.

Po znalezieniu rekordu procedura ustawia:

```text
Status        = PROCESSING
StartedAt     = bieżący czas
LastAttemptAt = bieżący czas
AttemptCount  = AttemptCount + 1
WorkerToken   = token bieżącego workera
NextAttemptAt = NULL
ErrorMessage  = NULL
```

Dopiero wtedy transakcja jest zatwierdzana.

To eliminuje typową sytuację wyścigu, w której dwa procesy mogłyby najpierw odczytać ten sam rekord, a dopiero później próbować go aktualizować.

## Kolejność pobierania z kolejki

Procedura preferuje nowe zadania:

```text
NEW przed RETRY
```

A następnie wybiera starsze rekordy według `RequestedAt`.

W praktyce daje to zachowanie zbliżone do FIFO dla nowych zgłoszeń, z obsługą retry w drugiej kolejności.

## WorkerToken - lease konkretnej próby

`WorkerToken` działa jak identyfikator własności aktualnej próby.

Przykład:

```text
RequestId   = X
WorkerToken = AAA
Status      = PROCESSING
```

Tylko worker posiadający token `AAA` może oznaczyć ten rekord jako `DONE` albo zgłosić jego błąd.

Procedury `usp_CompleteExportRequest` i `usp_FailExportRequest` aktualizują rekord tylko wtedy, gdy jednocześnie zgadzają się:

```text
RequestId
Status = PROCESSING
WorkerToken
```

Jeżeli token już nie pasuje, procedura zgłasza błąd. Dzięki temu stary lub opóźniony worker nie może zakończyć zadania, które zostało już przejęte przez inny proces.

## Wykonanie eksportu

Po poprawnym claim worker buduje deterministyczną nazwę pliku:

```text
export-<RequestId>-customer-<CustomerId>-<yyyymmdd>.txt
```

Nazwa oparta o `RequestId` jest celowa. Jeżeli worker zapisze plik, ale ulegnie awarii przed zmianą statusu w SQL Server, ponowna próba będzie używać tej samej nazwy zamiast tworzyć kolejne duplikaty.

W POC zapis pliku tekstowego zastępuje właściwy executor SSIS. W środowisku produkcyjnym ten fragment może zostać zastąpiony wykonaniem pakietu SSIS bez zmiany modelu kolejki i tożsamości.

## Sukces

Po utworzeniu pliku worker sprawdza jego istnienie i wywołuje:

```text
dbo.usp_CompleteExportRequest
```

Procedura ustawia:

```text
Status        = DONE
FinishedAt    = bieżący czas
OutputFile    = pełna ścieżka pliku
ErrorMessage  = NULL
NextAttemptAt = NULL
WorkerToken   = NULL
```

Warunek `WorkerToken` sprawia, że rekord może zakończyć tylko proces, który go faktycznie przejął.

# Jak działa retry - szczegółowo

## Pierwsza próba

Nowy rekord zaczyna od:

```text
Status       = NEW
AttemptCount = 0
MaxAttempts  = 3
```

Po pierwszym claim:

```text
Status       = PROCESSING
AttemptCount = 1
```

Jeżeli wykonanie kończy się błędem, worker wywołuje:

```text
dbo.usp_FailExportRequest
```

Procedura porównuje `AttemptCount` z `MaxAttempts`.

Jeżeli zostały jeszcze próby:

```text
AttemptCount < MaxAttempts
```

ustawiane jest:

```text
Status        = RETRY
NextAttemptAt = bieżący czas + RetryDelaySeconds
ErrorMessage  = treść błędu
WorkerToken   = NULL
FinishedAt    = NULL
```

Domyślnie:

```text
RetryDelaySeconds = 60
```

Do momentu nadejścia `NextAttemptAt` rekord nie kwalifikuje się do kolejnego claim.

## Kolejne próby

Przy następnym uruchomieniu joba rekord `RETRY` zostanie przejęty tylko wtedy, gdy:

```text
NextAttemptAt <= bieżący czas
```

Claim zwiększa licznik:

```text
AttemptCount = AttemptCount + 1
```

Każda kolejna próba otrzymuje nowy `WorkerToken`.

Dla domyślnej konfiguracji przebieg wygląda tak:

```text
NEW
AttemptCount = 0

  |
  v

PROCESSING - próba 1/3
  |
  +-- sukces --> DONE
  |
  +-- błąd --> RETRY (+60 s)
                    |
                    v
             PROCESSING - próba 2/3
                    |
                    +-- sukces --> DONE
                    |
                    +-- błąd --> RETRY (+60 s)
                                      |
                                      v
                               PROCESSING - próba 3/3
                                      |
                                      +-- sukces --> DONE
                                      |
                                      +-- błąd --> FAILED
```

Po wykorzystaniu ostatniej próby ustawiane jest:

```text
Status        = FAILED
FinishedAt    = bieżący czas
NextAttemptAt = NULL
ErrorMessage  = ostatni błąd
WorkerToken   = NULL
```

Rekord `FAILED` nie jest już automatycznie pobierany przez worker.

## MaxItems

Worker przy jednym uruchomieniu obsługuje maksymalnie:

```text
MaxItems = 10
```

Po zakończeniu jednego rekordu próbuje pobrać następny. Jeżeli nie ma żadnego kwalifikującego się zadania, kończy pracę komunikatem:

```text
No eligible queue items.
```

Limit zapobiega sytuacji, w której pojedyncze uruchomienie joba przejmowałoby nieograniczoną liczbę rekordów.

## Status joba SQL Agent przy błędach

Worker prowadzi licznik błędów. Jeżeli podczas jednego uruchomienia wystąpi co najmniej jeden błąd, stan kolejki może być poprawnie zapisany jako `RETRY` albo `FAILED`, ale sam krok SQL Agent kończy się błędem.

Przykład:

```text
9 rekordów -> DONE
1 rekord    -> RETRY
SQL Agent job -> Failed
```

W POC jest to celowe: operator ma zobaczyć, że podczas wykonania wystąpił problem, mimo że mechanizm retry zadziałał prawidłowo.

W produkcji można przyjąć inną politykę, np. uznać job za sukces, jeśli wszystkie błędy zostały prawidłowo zapisane do kolejki i oczekują na retry.

# Ograniczenie POC - rekord osierocony w PROCESSING

Obecny Stage 5 nie implementuje automatycznego odzyskiwania rekordu, który pozostał w `PROCESSING` po nagłym przerwaniu workera.

Przykładowy scenariusz:

```text
1. Worker wykonuje claim.
2. Status = PROCESSING.
3. SQL64 restartuje się albo proces PowerShell zostaje zabity.
4. Nie zostaje wykonane Complete ani Fail.
5. Rekord pozostaje w PROCESSING.
```

Taki rekord nie zostanie ponownie pobrany, ponieważ `usp_ClaimExportRequest` bierze tylko `NEW` i `RETRY`.

W produkcji należy dodać politykę recovery, np.:

```text
PROCESSING
AND StartedAt < DATEADD(MINUTE, -30, SYSDATETIME())
```

oraz procedurę, która po przekroczeniu ustalonego timeoutu przeniesie rekord do:

```text
RETRY
```

albo do:

```text
FAILED
```

zależnie od przyjętej polityki operacyjnej.

W takim rozwiązaniu warto również zapisać przyczynę recovery w `ErrorMessage` i monitorować liczbę osieroconych zadań.

# Podsumowanie mechanizmu workera

Worker można traktować jako konsumenta kolejki z leasingiem konkretnej próby:

```text
claim
  -> WorkerToken
  -> PROCESSING
  -> wykonanie
       |
       +--> success -> complete -> DONE
       |
       +--> error   -> fail -> RETRY -> kolejny claim
                              |
                              +--> po MaxAttempts -> FAILED
```

Najważniejsze elementy tego modelu to:

- aplikacja tylko składa zlecenie,
- wykonanie jest asynchroniczne,
- rekord jest atomowo przejmowany przez jednego workera,
- `WorkerToken` chroni własność konkretnej próby,
- retry ma kontrolowany limit i opóźnienie,
- deterministyczna nazwa pliku ogranicza ryzyko duplikatów,
- konto wykonawcze ma tylko interfejs procedur, bez bezpośredniego CRUD do kolejki.

## Ważne dla produkcji

Ten Stage 5 kończy POC modelu bezpieczeństwa i orkiestracji. Sam zapis pliku tekstowego jest tylko zastępczym executorem. Na środowisku z pełnym SSIS worker może wywołać pakiet SSIS pod tą samą dedykowaną tożsamością wykonawczą.

Model bezpieczeństwa pozostaje bez zmian:

```text
aplikacja != executor
```

Aplikacja tylko składa zlecenie. Konto techniczne wykonuje eksport i uwierzytelnia się do SMB bezpośrednio jako `SQLLAB\poc-ssis-export`.
