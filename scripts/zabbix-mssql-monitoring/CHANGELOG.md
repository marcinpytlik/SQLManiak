# Changelog

## v1.6 — baseline/anomaly
- rolling E2E average 1h/24h,
- MAD 24h,
- anomaly score i ratio do baseline,
- seasonal `baselinewma` / `baselinedev`,
- database discovery heartbeat 5m.

## v1.5.1 — E2E Alpine fix
- external script używa `/proc/uptime` zamiast `date +%s%N`.

## v1.5 — full-path E2E
- raw/status/response_ms/zabbix_get_rc/sql_utc,
- external check wykonywany po stronie Zabbix Server/Proxy.

## v1.4 — capacity
- VLF per DB i max,
- ROWS time-to-full.

## v1.3 — discovery hardening
- szybszy DB discovery,
- stabilniejsze per-DB prototypes,
- TDE value mapping.

## v1.2 — collector pack
- CPU/scheduler,
- I/O latency,
- long transactions,
- CPU per DB,
- DB space,
- filegroups,
- TDE.
