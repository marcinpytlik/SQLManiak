# Excel → Zabbix: alerty per instancja, per baza i CPU per baza

## Alerty per instancja

| ID | Alert z Excela | Status | Co jest w template |
|---|---|---|---|
| I-01 | TCP port unavailable | ✅ | Trigger `MSSQL: TCP port unavailable` |
| I-02 | ODBC unavailable while TCP is UP | ✅ | `MSSQL: Monitoring channel unavailable while TCP is reachable` — semantyka ODBC zastąpiona kanałem Agent 2 |
| I-03 | Unexpected SQL Server restart | ✅ | `MSSQL: SQL Server restarted unexpectedly` |
| I-04 | SQL CPU pressure correlated with scheduler pressure | 🟡 | Metryki relative CPU/runnable/SOS yield/E2E są; skorelowany trigger CPU pressure pozostawiony na etap progów |
| I-05 | Other processes CPU high | 🟡 | `mssql.cpu.other_utilization` jest; dedykowany trigger progu nie został dodany |
| I-06 | Memory Grants Pending persistent | ✅ | WARNING + HIGH dla Memory Grants Pending |
| I-07 | Free List Stalls persistent | ✅ | WARNING + HIGH dla Free List Stalls |
| I-08 | Read latency high | 🟡 | `mssql.io.read_stall_ms` jest; alert latency pozostawiony do strojenia progów |
| I-09 | Write latency high | 🟡 | `mssql.io.write_stall_ms` jest; alert latency pozostawiony do strojenia progów |
| I-10 | Blocking correlated with lock pressure | ✅ | `Blocking correlated with lock pressure` + `Blocking has measurable workload impact` |
| I-11 | Deadlock detected / burst | ✅ | `Deadlock detected` + `Deadlock burst detected` |
| I-12 | Long transaction | 🟡 | Metryki count/max duration są; trigger long transaction nie został jeszcze aktywowany |

## Alerty per baza

| ID | Alert z Excela | Status | Co jest w template |
|---|---|---|---|
| DB-01 | Database state != ONLINE | ✅ | Dwa triggery: non-critical HIGH i critical DISASTER |
| DB-02 | Log used % high | ✅ | Percent log used WARNING/HIGH |
| DB-03 | Estimated log time-to-full | 🟡 | `mssql.db.log_timeleft` jest; trzy rozłączne progi TTL z arkusza nie są aktywne |
| DB-04 | ROWS data used % | 🟡 | ROWS used % i time-to-full są; progi ROWS % nie są jeszcze aktywne |
| DB-05 | FULL backup overdue | ✅ | FULL backup WARNING/HIGH |
| DB-06 | DIFF backup overdue | ✅ | DIFF backup WARNING/HIGH |
| DB-07 | LOG backup overdue | ✅ | LOG backup WARNING/HIGH |
| DB-08 | Recovery model expected state | 🟡 | Recovery model item jest; expected-state policy trigger nieaktywny |
| DB-09 | Filegroup used % | 🟡 | Filegroup used % item jest; trigger progowy nieaktywny |
| DB-10 | Filegroup free MB low | 🟡 | Filegroup free MB item jest; trigger progowy nieaktywny |
| DB-11 | TDE expected state | 🟡 | TDE per DB jest (`tde_encrypted`, `tde_state`), ale policy/required trigger nieaktywny |
| DB-12 | CPU workload share per DB | ✅ | `mssql.db.cpu_share_pct` działa jako trend |
| DB-13 | CPU capacity utilization per DB | ✅ | `mssql.db.cpu_capacity_pct` działa jako trend |
| DB-14 | CPU anomaly correlated with instance pressure | ⏳ | Per-DB anomaly trigger nie został dodany; baseline/anomaly v1.6 dotyczy obecnie E2E |

## CPU per baza

| ID | Metryka | Status | Implementacja |
|---|---|---|---|
| DBCPU-01 | CPU time delta per DB | ✅ | `mssql.db.cpu_time_ms.delta` |
| DBCPU-02 | CPU ms per second per DB | ✅ | `mssql.db.cpu_ms_per_sec` |
| DBCPU-03 | CPU share of SQL workload per DB | ✅ | `mssql.db.cpu_share_pct` |
| DBCPU-04 | CPU capacity utilization per DB | ✅ | `mssql.db.cpu_capacity_pct` |
| DBCPU-05 | Top CPU database rank | ⏳ | Ranking per DB nie został dodany |
| DBCPU-06 | CPU anomaly per DB | ⏳ | Anomaly per DB nie został dodany; anomaly v1.6 obejmuje E2E |

## Najważniejsze różnice względem Excela

1. **ODBC → Agent 2 MSSQL plugin.** Arkusz powstawał wokół `db.odbc.get[...]`; implementacja używa oficjalnego MSSQL pluginu Agent 2 oraz `mssql.custom.query[...]`.
2. **E2E jest pełniejsze niż w Excelu.** `mssql.e2e.response_ms` mierzy round-trip z kontenera Zabbix Server przez `zabbix_get`, Agent 2 i MSSQL plugin do SQL Server i z powrotem.
3. **CPU jest znormalizowane względem schedulerów SQL.** Dodano host logical CPU, visible schedulers, runnable queue, SOS_SCHEDULER_YIELD, relative CPU oraz CPU per DB.
4. **Capacity zostało rozbudowane.** Są ROWS used/free/allocated, filegroupy, VLF per DB i max, plus ROWS `timeleft()`.
5. **TDE jest per DB.** Template ma `mssql.db.tde_encrypted` i `mssql.db.tde_state`.
6. **Baseline/anomaly v1.6 dotyczy E2E.** Per-DB CPU anomaly z Excela nadal pozostaje do zrobienia.
7. **Progi celowo nie są wszędzie aktywne.** W I/O, filegroups, ROWS i części CPU najpierw zbieramy baseline.
