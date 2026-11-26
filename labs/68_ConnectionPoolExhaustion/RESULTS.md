# Lab 68 — Results (2026-11-26)

Environment: SQL Server 2022 Developer CU28, 16.0.4325.4, Ubuntu 22.04.5, .NET 10 / EF Core 10, EF Core 10.0.15; Microsoft.Data.SqlClient 6.1.7 (assembly 6.0.0.0), SNI runtime 6.0.3. Local Docker.

| Scenario | Observed result |
|---|---|
| Baseline | 10/10 success, SPID 53, times 590,25,83,2,2,2,2,1,2,2 ms; median 2 ms |
| Exhaustion | SPIDs 60,62,63 sleeping; no active requests or transactions in samples; fourth acquisition timeout 5021 ms |
| Recovery | Same process, SPID 63 reused, 5 ms, exit 0 |
| Transaction | SPID 53, transaction 13578 active after DisposeAsync; last active sample 21:04:02.002 UTC, first inactive 21:04:03.101 UTC; same SPID and connect_time on reuse; probe 409 ms; exit 0 |

Transaction began 21:03:32.363 UTC. No DML in this initial transaction test. DMV sampling is not continuous tracing; exact reset mechanism not yet confirmed by XE. Initial exhaustion run exposed localized exception filter bug, fixed in 44bf105; successful rerun reported above. The subsequent tests below confirmed blocking, explicit rollback, counters and connection reset. No general claims about all provider versions or isolation levels.

## Blocking and rollback control

- Blocking: owner SPID 60 disposed at 21:13:50.698 UTC; observer SPID 59 pending after 10 s. Nine DMV samples show owner sleeping with one open transaction, observer request suspended on LCK_M_S, blocker 60. Reuse at 21:14:00.714 UTC reports @@TRANCOUNT=0; observer returns original value 0.
- XE: rpc_completed sp_reset_connection on SPID 60 at 21:14:00.711 UTC, duration 281 microseconds, result OK; cached logout/login events around reset. Ring buffer reported 8 events, droppedCount=0, truncated=0. Observer was outside the XE application filter; its completion is evidenced by application output.
- Explicit rollback: observer completed before the 10-second checkpoint, value 0; no LCK_M_* samples. Original reported elapsed times 10014/10012 ms included the deliberate observation window, not isolated SELECT latency. Corrected timing requires rerun.

## Repeat exhaustion with EventCounters

Tool: dotnet-counters 10.0.750501. Run 20261126-212001781. Held SPIDs 68,69,70; timeout 5015 ms at 21:20:40.081 UTC; release 21:20:55.102 UTC; recovery SPID 70 in 6 ms.

| UTC sample interval (inclusive) | Samples | Active | Ready | Pooled | Pools |
|---|---:|---:|---:|---:|---:|
| 21:20:05–21:20:54 | 50 | 3 | 0 | 3 | 1 |
| 21:20:55–21:21:04 | 10 | 0 | 3 | 3 | 1 |

60 timestamp groups, 240 selected counter values; local CSV timestamps converted from CET (UTC+1). The transient recovery checkout is shorter than sampling resolution and not visible in these samples. Counters establish pool state, whereas earlier DMV runs establish sleeping sessions are not proof of available pool slots. These observations apply to the tested configuration, not every provider or transaction API.
