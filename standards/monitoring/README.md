# Standard: Monitoring

## Purpose

Zapewnić spójne monitorowanie dostępności, ochrony danych, wydajności i capacity bez tworzenia alarmów opartych wyłącznie na przypadkowych progach.

## Scope

Wszystkie produkcyjne instancje SQL Server oraz bazy objęte operacyjnym wsparciem DBA.

## Requirements

### Required

Monitoring obejmuje co najmniej:

#### Instance

- dostępność TCP,
- dostępność kanału monitoringu / E2E,
- restart SQL Server,
- krytyczne błędy,
- pamięć,
- blocking,
- deadlocks,
- stan SQL Agent / critical jobs.

#### Database

- stan bazy,
- wiek backupów FULL/DIFF/LOG zgodnie z użyciem,
- log usage/capacity,
- recovery model jako metadane,
- file/filegroup capacity,
- TDE state tam, gdzie wymagana polityką.

#### HA/DR

- quorum,
- replica role,
- connected state,
- synchronization health,
- log send queue,
- redo queue.

### Recommended

- Rozdzielać metryki na:
  - ALERT,
  - TREND,
  - DIAGNOSTIC.
- Najpierw zebrać baseline, potem aktywować progi dla metryk silnie zależnych od workloadu.
- Dla CPU korelować:
  - SQL CPU,
  - VISIBLE ONLINE schedulers,
  - runnable queue,
  - SOS_SCHEDULER_YIELD,
  - E2E/application latency.
- Dla blocking korelować blokady z lock waits/timeouts i impact.
- Stosować anomaly/baseline tam, gdzie stały próg jest słaby.

### Not allowed

- Alertowanie wyłącznie na podstawie pojedynczej metryki bez kontekstu, jeśli metryka zależy od workloadu.
- Ustawianie arbitralnych progów I/O/CPU/filegroup tylko dlatego, że „tak jest w internecie”.
- Traktowanie każdej metryki jako alertu.
- Brak monitoringu missed SQL Agent runs.
- Brak monitoringu backup SLA.

## Default configuration

Model:

```text
Availability
+
Data protection
+
Capacity
+
Performance signals
+
HA/DR
+
Automation
+
E2E
```

Severity powinna zależeć od impact i krytyczności obiektu.

## Exceptions

Jeżeli dany sygnał nie jest monitorowany, dokumentacja musi wskazać:

- dlaczego,
- alternatywny mechanizm,
- ownera,
- plan/termin uzupełnienia.

## Validation

- coverage matrix,
- stan itemów/collectorów,
- test alertu,
- test kanału notification,
- dashboard/trend history,
- mapowanie alert → troubleshooting/runbook.

## Ownership

DBA / Monitoring Platform Owner.

## Review cycle

- miesięcznie dla coverage,
- po dodaniu nowej bazy/instancji,
- po zmianie topologii HA,
- po incydencie,
- po zmianie baseline/workloadu.

## References

- [Monitoring Matrix](../../scripts/zabbix-mssql-monitoring/docs/excel-mapping/03-alerts-and-cpu.md)
- [Zabbix MSSQL Monitoring](../../scripts/zabbix-mssql-monitoring/)
- [Monitoring Hub](../../monitoring/)
- [Troubleshooting Hub](../../troubleshooting/)
- [Runbooks Hub](../../runbooks/)
