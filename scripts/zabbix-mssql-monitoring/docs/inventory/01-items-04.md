# Inventory — items instancji

Łącznie: **139**. Opis pochodzi z aktualnego YAML; „Jak” wskazuje faktyczny mechanizm zbierania.

| Nazwa | Key | Jak | Co mierzy / sens |
|---|---|---|---|

> Część 4.

| SQLManiak E2E: anomaly score 24h | `mssql.e2e.anomaly.score24h` | calculated: `abs(last(//mssql.e2e.response_ms)-avg(//mssql.e2e.response_ms,24h))/(mad(//mssql.e2e.response_ms,24h)+1)` | Robust anomaly score: absolute distance between current E2E response time and the 24-hour average, divided by MAD+1. Informational only in v1.6; no trigger threshold is enabled. |
| SQLManiak E2E: current vs 24h baseline ratio | `mssql.e2e.baseline.ratio24h` | calculated: `last(//mssql.e2e.response_ms)/(avg(//mssql.e2e.response_ms,24h)+1)` | Current E2E response time divided by the rolling 24-hour average (+1 ms guard). 1.0 means approximately baseline; >1 means slower than baseline. |
| SQLManiak E2E: seasonal baseline same hour 7d | `mssql.e2e.baseline.seasonal7d` | calculated: `baselinewma(//mssql.e2e.response_ms,1h:now/h,"d",7)` | Seasonal baseline using Zabbix baselinewma: same full hour-of-day across the previous 7 days. Requires sufficient trend history; expect a warm-up period before values become meaningful. |
| SQLManiak E2E: seasonal deviation same hour 7d | `mssql.e2e.anomaly.seasonaldev7d` | calculated: `baselinedev(//mssql.e2e.response_ms,1h:now/h,"d",7)` | Zabbix baselinedev for the previous full hour compared with the same hour-of-day in the prior 7 days. Returns the number of population-standard-deviation units. Informational only; no trigger in v1.6. |
