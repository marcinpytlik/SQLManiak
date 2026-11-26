# Lab 68 — Results (2026-11-26)

Environment: SQL Server 2022 Developer CU28, 16.0.4325.4, Ubuntu 22.04.5, .NET 10 / EF Core 10, SqlClient assembly 6.0.0.0 (exact NuGet version pending). Local Docker.

| Scenario | Observed result |
|---|---|
| Baseline | 10/10 success, SPID 53, times 590,25,83,2,2,2,2,1,2,2 ms; median 2 ms |
| Exhaustion | SPIDs 60,62,63 sleeping; no active requests or transactions in samples; fourth acquisition timeout 5021 ms |
| Recovery | Same process, SPID 63 reused, 5 ms, exit 0 |
| Transaction | SPID 53, transaction 13578 active after DisposeAsync; last active sample 21:04:02.002 UTC, first inactive 21:04:03.101 UTC; same SPID and connect_time on reuse; probe 409 ms; exit 0 |

Transaction began 21:03:32.363 UTC. No DML in this initial transaction test. DMV sampling is not continuous tracing; exact reset mechanism not yet confirmed by XE. Initial exhaustion run exposed localized exception filter bug, fixed in 44bf105; successful rerun reported above. Blocking, explicit rollback, counters and XE pending. No general claims about all provider versions or isolation levels.
