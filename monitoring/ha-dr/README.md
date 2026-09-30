# Monitoring: HA / DR

## Purpose

Monitorować stan ochrony WSFC/FCI/AG oraz kolejki wpływające na realne RPO/RTO.

## Signals / Metrics

- quorum state/type/member state
- AG replica role
- connected state
- synchronization health
- log send queue
- redo queue
- listener availability

## Alert vs Trend

- quorum unhealthy — ALERT
- replica disconnected — ALERT
- sync health unhealthy — ALERT
- send/redo queues — TREND + ALERT po strojenia progu
- role change — EVENT/ALERT depending context

## Baseline

Send/redo queue oceniaj względem workloadu, trybu sync/async i realnego RPO, nie stałego progu oderwanego od systemu.

## Correlation

- quorum vs node events
- send queue vs network/log generation
- redo queue vs secondary storage/CPU
- listener vs client connectivity

## Severity

DISASTER/HIGH dla utraty Primary/quorum lub niedostępności krytycznej bazy; queue backlog severity zależy od ryzyka RPO.

## Validation

- cluster state
- replica DMVs
- listener connection
- failover test
- RPO/RTO review

## Troubleshooting

- [HA/DR](../../troubleshooting/ha-dr/)

## Runbooks

- [FCI Failover](../../runbooks/fci-failover/)
- [AG Planned Failover](../../runbooks/ag-planned-failover/)
- [Log Shipping DR](../../runbooks/log-shipping-dr-failover/)

## Sources of truth

- [Zabbix HA prototypes](../../scripts/zabbix-mssql-monitoring/docs/inventory/02-prototypes-02.md)
- [HA/DR Standard](../../standards/ha-dr/)
