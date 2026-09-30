# SQL Agent Job Recovery — RUNBOOK

## 1. Usuń root cause

Napraw permission/path/login/context/dependency.

## 2. Wybierz bezpieczny punkt restartu

Nie restartuj całego joba bez oceny idempotencji.

## 3. Uruchom kontrolowanie

Zapisz timestamp i historię.

## 4. Sprawdź retry/duration

Potwierdź końcowy status i SLA.

## 5. Zweryfikuj output

Sprawdź backup/plik/raport/dane.

Po wykonaniu przejdź do [VALIDATION.md](VALIDATION.md).
