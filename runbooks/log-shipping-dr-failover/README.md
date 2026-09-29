# Runbook: Log Shipping DR Failover

## Cel

Przełączenie usługi na bazę DR utrzymywaną przez Log Shipping, z maksymalnym możliwym domknięciem log chaina.

## Kiedy użyć

- awaria Primary
- planowany test DR
- utrata głównej instancji przy działającym Log Shipping

## Struktura

- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth

- [Log Shipping Implementation Guide](../../labs/05-ha_dr/logshipping/docs/LogShipping_Implementation_Guide.md)
- [Backup/Restore runbook](../backup-restore-recovery/)

## Zasada

> Przed RECOVERY na secondary upewnij się, że odtworzono cały dostępny i wymagany log chain — RECOVERY kończy możliwość dokładania kolejnych log backupów.
