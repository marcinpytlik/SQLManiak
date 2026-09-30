# Runbook: Availability Group Planned Failover

## Cel

Kontrolowane przełączenie roli Primary na przygotowaną replikę Secondary z minimalnym ryzykiem utraty danych i walidacją listenera oraz synchronizacji.

## Kiedy użyć

- planowane maintenance Primary
- test DR/HA
- kontrolowana zmiana roli replik

## Struktura

- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth

- [HA/DR troubleshooting](../../troubleshooting/ha-dr/)
- [Zabbix HA prototypes](../../scripts/zabbix-mssql-monitoring/docs/inventory/02-prototypes-02.md)

## Zasada

> Failover jest zakończony dopiero wtedy, gdy nowy Primary obsługuje ruch, listener działa, a pozostałe repliki wracają do oczekiwanego stanu.
