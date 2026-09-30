# Monitoring: Blocking & Deadlocks

## Purpose

Wykrywać blocking z realnym wpływem oraz deadlocki, a nie alarmować na każdą chwilową blokadę.

## Signals / Metrics

- processes blocked
- lock waits/sec
- lock timeouts/sec
- average lock wait time
- deadlock count/burst
- long transaction duration

## Alert vs Trend

- blocking correlated with lock pressure — ALERT
- blocking with measurable workload impact — ALERT
- deadlock detected/burst — ALERT
- raw lock waits — TREND/DIAGNOSTIC

## Baseline

Czas i liczba blokad zależą od workloadu. Alert ma sens po korelacji z waits/timeouts/impact.

## Correlation

- blocking chain vs LCK_M waits
- blocking vs long transactions
- deadlock graph vs affected queries
- timeouts vs application latency

## Severity

Deadlock burst lub blocking krytycznego workloadu może być HIGH; pojedynczy krótki blocker zwykle nie.

## Validation

- blocking snapshot
- deadlock graph
- lock waits/timeouts
- application impact

## Troubleshooting

- [Blocking](../../troubleshooting/blocking/)
- [Deadlocks](../../troubleshooting/deadlocks/)

## Runbooks

- [Blocking Emergency](../../runbooks/blocking-emergency/)
- [Deadlock Incident Response](../../runbooks/deadlock-incident-response/)

## Sources of truth

- [Zabbix alerts matrix](../../scripts/zabbix-mssql-monitoring/docs/excel-mapping/03-alerts-and-cpu.md)
- [Blocking Snapshot](../../scripts/t-sql/Reques_PerfPack/03_Blocking_Snapshot.sql)
