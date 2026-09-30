# Log Shipping DR Failover — RUNBOOK

## 1. Zatrzymaj lub zamroź writes na Primary, jeśli jest dostępny

Zapobiega to dalszej rozbieżności podczas kontrolowanego DR.

## 2. Wykonaj tail-log backup, jeśli możliwe

Użyj tego tylko gdy stan Primary na to pozwala i jest to część zatwierdzonego planu recovery.

## 3. Dostarcz brakujące log backupy

Skopiuj i odtwórz wszystkie wymagane pliki na Secondary z NORECOVERY/STANDBY zgodnie z konfiguracją.

## 4. Zakończ recovery

Gdy nie ma już logów do dołożenia, wykonaj RESTORE DATABASE [db] WITH RECOVERY.

## 5. Przełącz aplikację

Zmień routing/DNS/connection string zgodnie z planem DR.

## Przejście do walidacji

Po wykonaniu procedury przejdź do [VALIDATION.md](VALIDATION.md).
