# Stage 4 — Resilience / Recovery

## Cel

Sprawdzić, czy rozwiązanie zachowuje się przewidywalnie po awariach, restartach i zmianach warunków pracy.

## Testy

Wykonuj zgodnie z `Tests/README.md`:

```text
01 Restart Connect
02 Restart Kafka
03 Restart SQL Server
04 Backlog recovery
05 Rollback
06 Schema evolution
07 Retention / LSN gap
08 Ordering / duplicates
09 Operational checks
```

## Kryterium PASS

Etap jest zaliczony, gdy dla każdego testu zapisano wynik i obserwacje, a zachowanie systemu jest zgodne z oczekiwaniem lub ma udokumentowaną procedurę recovery.

## Najważniejsze zasady

- restart Connect nie powinien powodować utraty zmian, jeśli wymagane LSN nadal są objęte retencją CDC,
- rollback nie powinien generować zatwierdzonego eventu biznesowego,
- utrata LSN wymaga jawnego re-init zamiast prób „zgadywania” offsetu,
- schema evolution musi być kontrolowana i testowana z capture instance v2,
- consumer powinien być projektowany jako idempotentny.

## LAB-ONLY

Test retention/LSN gap może celowo doprowadzić do utraty historii CDC. Wykonuj go na końcu.
