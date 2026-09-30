# Monitoring: Query Store

## Purpose

Monitorować stan Query Store jako źródła historii performance i wykrywać utratę możliwości zbierania danych.

## Signals / Metrics

- actual_state_desc
- desired_state_desc
- storage used/max
- readonly_reason
- forced plan failures
- number of plans/regressions

## Alert vs Trend

- unexpected READ_ONLY — ALERT/compliance
- storage nearing max — ALERT/TREND
- force failures — ALERT
- runtime regressions — DIAGNOSTIC

## Baseline

Rozmiar i liczba planów zależą od bazy; monitoruj trend oraz stan operacyjny.

## Correlation

- READ_ONLY vs storage cap
- regression vs deployment/compatibility change
- force failure vs plan evolution
- runtime stats vs waits/CPU

## Severity

HIGH dla krytycznej bazy, gdy Query Store przestaje zbierać dane podczas aktywnego okresu diagnostycznego.

## Validation

- Query Store options
- runtime stats
- forced plans
- storage trend

## Troubleshooting

- [Query Store](../../troubleshooting/query-store/)

## Runbooks

- [Query Store Regression](../../runbooks/query-store-regression-mitigation/)

## Sources of truth

- [Query Store Checklist](../../labs/QueryStore/checklists/QueryStore-Checklist.md)
- [Query Store Standard](../../standards/query-store/)
