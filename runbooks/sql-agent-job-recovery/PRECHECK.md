# SQL Agent Job Recovery — PRECHECK

## Sprawdzenia
1. Sprawdź usługę Agent.
2. Sprawdź job/schedule enabled.
3. Znajdź pierwszy błędny step.
4. Zapisz message/subsystem/command.
5. Ustal owner/proxy/credential.
6. Sprawdź dependency i idempotencję przed retry.

## Evidence before
- job id/name
- failed step
- message
- execution context
- SQLAGENT.OUT

## Stop conditions
- ponowne uruchomienie może zdublować operację
- nie wiadomo, które kroki już wykonały zmianę
- dependency nadal niedostępna
