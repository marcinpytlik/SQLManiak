# Standard: SQL Server Agent

## Purpose

Zapewnić, że automatyzacja SQL Server jest przewidywalna, monitorowana, posiada właściwy execution context i nie zależy od kont osobistych.

## Scope

Wszystkie produkcyjne SQL Server Agent jobs oraz krytyczne joby w środowiskach DR/test.

## Requirements

### Required

- Krytyczny job ma technicznego ownera, nie konto osobiste.
- Job ma udokumentowany cel i właściciela.
- Job planowany cyklicznie ma aktywny schedule.
- Krytyczne joby mają monitoring failed/missed run.
- Dla PowerShell/CmdExec/SSIS execution context jest jawnie określony przez właściwy proxy/credential, jeśli wymagane.
- Database Mail/operator działa dla jobów wymagających powiadomienia.
- Disabled jobs są kontrolowane i mają uzasadnienie.
- Po migracji/patchingu walidowane są owner, proxy, credential, schedules i output.

### Recommended

- Rozróżniać:
  - failed,
  - canceled,
  - retry,
  - long-running,
  - missed run,
  - disabled.
- Dla maintenance windows używać snapshotu stanu jobów i przywracać tylko te wcześniej włączone.
- Krytyczny job walidować przez jego rezultat, nie tylko `RunStatus = Succeeded`.

### Not allowed

- Konta osobiste jako trwały owner krytycznych jobów.
- Szerokie prawa tylko dlatego, że job „nie działa”.
- Retry jako substytut root cause analysis.
- Wyłączanie jobów bez śladu/uzasadnienia.
- Poleganie wyłącznie na mailu jako monitoringu jobów.

## Default configuration

Krytyczny job powinien mieć:

```text
technical owner
schedule / on-demand classification
notification
monitoring
documented dependencies
known execution context
output validation
```

## Exceptions

Wyjątek musi określać:

- job,
- owner,
- reason,
- brakujący element standardu,
- termin usunięcia wyjątku.

## Validation

- `msdb.dbo.sysjobs`,
- `sysjobschedules`,
- `sysjobhistory`,
- DBACentralRepository compliance,
- Database Mail logs,
- DBA Daily Pack Agent Health.

## Ownership

DBA / właściciel automatyzacji.

## Review cycle

- miesięcznie,
- po migracji,
- po patchingu,
- po zmianie kont usług/proxy,
- po incydencie joba.

## References

- [SQL Agent Troubleshooting](../../troubleshooting/sql-agent/)
- [SQL Agent Recovery Runbook](../../runbooks/sql-agent-job-recovery/)
- [SQL Agent Patching Module](../../scripts/sql-agent-work-calendar-patching/README.md)
