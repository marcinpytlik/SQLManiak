# Monitoring: SQL Server Agent

## Purpose

Wykrywać failed, missed, long-running i disabled jobs oraz problemy z powiadomieniami.

## Signals / Metrics

- job status
- last run time
- expected vs actual run
- retry/canceled
- job enabled/schedule enabled
- Database Mail failures

## Alert vs Trend

- failed critical job — ALERT
- missed critical run — ALERT
- disabled critical job — ALERT/compliance
- duration — TREND
- retry count — DIAGNOSTIC

## Baseline

Czas trwania i częstość wykonania powinny być porównywane do historycznego zachowania konkretnego joba.

## Correlation

- job status vs SQL Agent service
- step failures vs owner/proxy/credential
- backup job vs backup SLA
- long-running step vs blocking/waits

## Severity

Severity zależy od krytyczności procesu; failed log backup job jest ważniejszy niż failed job raportowy.

## Validation

- sysjobhistory
- sysjobactivity
- SQLAGENT.OUT
- Database Mail logs
- artifact/output

## Troubleshooting

- [SQL Agent](../../troubleshooting/sql-agent/)

## Runbooks

- [SQL Agent Job Recovery](../../runbooks/sql-agent-job-recovery/)
- [SQL Server Patching](../../runbooks/sql-server-patching/)

## Sources of truth

- [DBA Daily Pack Agent Health](../../tools/DBADaillyPack/sql/02_Agent_Jobs_Health.sql)
- [SQL Agent Standard](../../standards/sql-agent/)
