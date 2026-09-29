# Troubleshooting: Replication

## Symptoms

- rosnący backlog,
- błędy Distribution Agent / Log Reader / Merge Agent,
- niedostarczone komendy,
- zatrzymany agent,
- błędy danych lub schema mismatch,
- wzrost latency publisher → subscriber.

## First checks

1. Status jobów agentów.
2. Błędy w distribution database.
3. Historia agentów.
4. Pending commands.
5. Stan publikacji/subskrypcji.
6. SQL Agent i connectivity.
7. Dopiero potem analiza konkretnego błędu.

## Existing source of truth

Pakiet [SQLManiak Replication Diagnostics](../../scripts/SQLManiak-Replication-Diagnostics/README.md):

- [1_jobs_status.sql](../../scripts/SQLManiak-Replication-Diagnostics/sql/1_jobs_status.sql)
- [2_distribution_errors.sql](../../scripts/SQLManiak-Replication-Diagnostics/sql/2_distribution_errors.sql)
- [3_merge_history.sql](../../scripts/SQLManiak-Replication-Diagnostics/sql/3_merge_history.sql)
- [4_health_checks.sql](../../scripts/SQLManiak-Replication-Diagnostics/sql/4_health_checks.sql)
- [5_pending_cmds_template.sql](../../scripts/SQLManiak-Replication-Diagnostics/sql/5_pending_cmds_template.sql)
- [6_alerts.sql](../../scripts/SQLManiak-Replication-Diagnostics/sql/6_alerts.sql)
- [Replication Errors Dashboard](../../scripts/SQLManiak-Replication-Diagnostics/sql/views/Replication_Errors_Dashboard.sql)

## Evidence to collect

- publication,
- subscriber,
- subscriber database,
- agent name,
- last action,
- error code,
- full error text,
- backlog/pending commands,
- latency,
- timestamp,
- ostatni poprawny przebieg.

## Validation

Po naprawie potwierdź:

- agent działa,
- backlog maleje,
- nowe komendy docierają,
- nie przybywają nowe błędy,
- dane na subscriberze są zgodne z oczekiwanym stanem.
