# Runbook: SQL Server Patching

## Cel

Kontrolowane patchowanie SQL Server z zachowaniem stanu jobów, weryfikacją usług i możliwością bezpiecznego wycofania zmiany.

## Kiedy użyć

- instalacja CU/GDR
- patching Windows wpływający na instancję
- maintenance FCI/standalone

## Struktura

- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth

- [SQL Agent patching window](../../scripts/sql-agent-work-calendar-patching/README.md)
- [DBA Monthly Checklist](../../tools/DBADaillyPack/checklists/DBA_Monthly_Checklist.md)
- [SQL Agent troubleshooting](../../troubleshooting/sql-agent/)

## Zasada

> Patching to zmiana usługowa: przed restartem zabezpiecz stan automatyzacji, a po restarcie waliduj nie tylko wersję, ale też realną usługę.
