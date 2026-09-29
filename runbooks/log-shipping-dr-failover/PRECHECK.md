# Log Shipping DR Failover — PRECHECK

## Kontekst

Zapisz:

```text
Server / instance:
Database / component:
Incident or change window:
Business impact:
Owner:
Expected result:
```

## Sprawdzenia przed wykonaniem

1. Sprawdź last_backup/last_copied/last_restored.
2. Ustal wymagany RPO i ostatni osiągalny punkt.
3. Jeśli Primary jest dostępny, oceń możliwość tail-log backup.
4. Potwierdź kompletność dostępnych plików log.
5. Ustal sposób przełączenia aplikacji/DNS/connection string.

## Evidence before

- last backup/copy/restore timestamps
- ostatni plik log
- RPO target
- stan Primary i Secondary

## Stop conditions

- nie wiadomo, który plik log jest ostatnim poprawnym elementem chaina
- secondary ma błędy restore
- biznes nie zaakceptował osiągalnego RPO
