# Monitoring: Transactional Replication

## Purpose

Wykrywać awarie agentów i rosnący backlog zanim subscriber przestanie spełniać SLA.

## Signals / Metrics

- Log Reader Agent status
- Distribution Agent status
- distribution errors
- pending commands/backlog
- latency
- distribution database capacity

## Alert vs Trend

- agent failed — ALERT
- distribution error — ALERT
- backlog/latency — TREND + ALERT by SLA
- distribution capacity — ALERT/TREND

## Baseline

Backlog musi być oceniany względem normalnego throughputu publication/subscription i dopuszczalnego SLA.

## Correlation

- agent failure vs SQL Agent
- backlog vs subscriber performance
- errors vs specific article/schema/data
- distribution capacity vs backlog

## Severity

HIGH, gdy backlog rośnie i grozi przekroczeniem SLA lub utratą ciągłości dostarczania danych.

## Validation

- agent history
- pending commands
- publisher/subscriber connectivity
- data freshness

## Troubleshooting

- [Replication](../../troubleshooting/replication/)

## Runbooks

- [Replication Incident Recovery](../../runbooks/replication-incident-recovery/)

## Sources of truth

- [Replication Diagnostics](../../scripts/SQLManiak-Replication-Diagnostics/README.md)
- [SQL Agent Monitoring](../sql-agent/)
