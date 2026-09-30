# ADR-005: Baseline-First Monitoring Instead of Universal Static Thresholds

- Status: Accepted
- Date: 2026-09-30
- Owners: SQLManiak / DBA

## Context

Repozytoryjny monitoring Zabbix zbiera szeroki zestaw metryk instancji i baz. Dla części sygnałów, np. I/O, filegroup capacity czy CPU, dokumentacja świadomie nie aktywuje uniwersalnych progów przed zebraniem rzeczywistych danych.

Jednocześnie istnieją sygnały binarne lub SLA-driven, gdzie alert jest jednoznaczny: database offline, failed critical job, backup age beyond policy, replica disconnected.

## Decision drivers

- ograniczenie false positives,
- uwzględnienie różnic workloadu,
- korelacja symptomów,
- rozdzielenie ALERT / TREND / DIAGNOSTIC.

## Considered options

### Stałe progi dla wszystkich środowisk

Odrzucono dla metryk silnie zależnych od workloadu.

### Baseline-first + korelacja

Przyjęto.

## Decision

Monitoring klasyfikuje sygnały jako:

```text
ALERT
TREND
DIAGNOSTIC
```

Zasady:

- binary availability/SLA signals mogą alertować bez baseline,
- CPU/I/O/capacity/performance thresholds są strojone na realnych danych,
- korelowane alerty są preferowane nad pojedynczym licznikiem,
- E2E może używać baseline/anomaly detection,
- severity zależy od business impact i criticality.

## Consequences

### Positive

- mniej arbitralnych alarmów,
- lepsze powiązanie alertu z realnym wpływem,
- monitoring wspiera troubleshooting zamiast generować szum.

### Negative / Trade-offs

- wymaga okresu zbierania historii,
- progi różnią się między systemami,
- potrzebny jest cykl przeglądu i strojenia.

## Validation

- coverage matrix,
- liczba actionable vs noisy alerts,
- test ścieżki alert → troubleshooting → runbook,
- okresowy review baseline.

## Revisit when

- zmienia się workload,
- zmienia się platforma monitoringowa,
- pojawia się nowy sygnał z silną semantyką SLA.

## References

- [Monitoring Standard](../../standards/monitoring/)
- [Zabbix Alert Matrix](../../scripts/zabbix-mssql-monitoring/docs/excel-mapping/03-alerts-and-cpu.md)
- [Monitoring Hub](../../monitoring/)
