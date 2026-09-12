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

## Retry

Jeżeli zapis pliku się nie powiedzie:

1. `AttemptCount` jest już zwiększony podczas claim,
2. `usp_FailExportRequest` ustawia `RETRY`, jeśli `AttemptCount < MaxAttempts`,
3. `NextAttemptAt` wyznacza moment następnej próby,
4. po ostatniej nieudanej próbie status przechodzi na `FAILED`.

Deterministyczna nazwa pliku oparta o `RequestId` ogranicza ryzyko duplikatów przy ponownym wykonaniu POC.

## Ważne dla produkcji

Ten Stage 5 kończy POC modelu bezpieczeństwa i orkiestracji. Sam zapis pliku tekstowego jest tylko zastępczym executorem. Na środowisku z pełnym SSIS worker może wywołać pakiet SSIS pod tą samą dedykowaną tożsamością wykonawczą.

Model bezpieczeństwa pozostaje bez zmian:

```text
aplikacja != executor
```

Aplikacja tylko składa zlecenie. Konto techniczne wykonuje eksport i uwierzytelnia się do SMB bezpośrednio jako `SQLLAB\poc-ssis-export`.
