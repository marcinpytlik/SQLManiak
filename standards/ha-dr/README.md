# Standard: HA / DR

## Purpose

Zapewnić, że mechanizmy wysokiej dostępności i disaster recovery odpowiadają krytyczności systemu oraz zdefiniowanym RPO/RTO.

## Scope

- FCI / WSFC,
- Availability Groups,
- Log Shipping,
- Backup / Restore jako recovery path,
- infrastruktura DR.

## Requirements

### Required

- Każdy system produkcyjny ma określoną krytyczność, RPO i RTO.
- Mechanizm HA/DR jest dobierany do wymagań, a nie traktowany jako domyślny dla każdej bazy.
- FCI i AG są traktowane jako różne mechanizmy i nie są dokumentacyjnie mieszane.
- WSFC/quorum/witness są monitorowane tam, gdzie używany jest klaster.
- Dla AG monitorowane są role, connected state, synchronization health, log send queue i redo queue.
- Listener/VNN jest częścią walidacji failover.
- Backup/restore pozostaje częścią DR również przy użyciu FCI/AG.
- Failover jest regularnie testowany.
- Failback jest traktowany jako osobna kontrolowana zmiana.
- Po failover mierzone są RTO i ewentualne data loss względem RPO.

### Recommended

Dla FCI zgodnie z repo:

- Test-Cluster bez krytycznych błędów przed wdrożeniem,
- skonfigurowane quorum,
- Preferred Owners,
- ręczny test failover,
- monitoring Eventów/ERRORLOG/storage,
- lokalny TempDB z identyczną ścieżką na node, jeśli przyjęto taki model.

Dla AG:

- znać availability mode i failover mode,
- interpretować send/redo queue razem ze stanem repliki,
- walidować aplikację przez listener.

### Not allowed

- Traktowanie HA jako zamiennika backupów.
- Failback automatycznie po powrocie node bez RCA.
- Zwiększanie heartbeat timeoutów bez evidence sieciowego.
- Deklarowanie sukcesu failover tylko na podstawie `ONLINE` resource.
- Forced failover bez świadomej akceptacji ryzyka utraty danych.

## Default configuration

Nie istnieje jeden domyślny mechanizm HA/DR dla każdej bazy.

Standard wymaga mapowania:

```text
Criticality
→ RPO
→ RTO
→ failure scenarios
→ HA mechanism
→ DR mechanism
→ tested recovery procedure
```

## Exceptions

System bez wymaganego HA/DR musi mieć formalnie zaakceptowane RPO/RTO oraz recovery path.

## Validation

- status WSFC/quorum,
- test failover,
- AG synchronization/queues,
- listener/VNN connectivity,
- test restore,
- zmierzony RTO,
- osiągnięte RPO.

## Ownership

DBA + Infrastructure + właściciel aplikacji.

## Review cycle

- co najmniej kwartalnie dla systemów krytycznych,
- po zmianie topologii,
- po patchingu/upgrade,
- po failover,
- po DR test.

## References

- [HA/DR Troubleshooting](../../troubleshooting/ha-dr/)
- [FCI Checklist](../../docs/FCI-Windows2022-SQL2022/docs/Checklist.md)
- [FCI Failover Runbook](../../runbooks/fci-failover/)
- [AG Planned Failover Runbook](../../runbooks/ag-planned-failover/)
- [Log Shipping DR Runbook](../../runbooks/log-shipping-dr-failover/)
