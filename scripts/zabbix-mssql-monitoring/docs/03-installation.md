# Instalacja SQLManiak MSSQL Zabbix 7.4

Dokument odtwarza konfigurację, którą faktycznie uruchomiliśmy i przetestowaliśmy.

## 1. Architektura

```text
Zabbix Server 7.4 (Docker/Compose)
        |
        | standardowe items + external E2E
        v
Zabbix Agent 2 (Windows, SQL64)
        |
        | MSSQL plugin, named session SQL3
        v
SQL Server named instance SQL3
```

Dla E2E:

```text
Zabbix Server container
 -> external script
 -> zabbix_get
 -> Agent 2 :10050
 -> MSSQL plugin
 -> SQL3
 -> sqlmaniak_e2e.sql
 -> odpowiedź
```

## 2. Wymagania

- Zabbix Server 7.4.
- Zabbix Agent 2 + MSSQL plugin 7.4 na serwerze SQL.
- Dostęp Zabbix Server/Proxy do Agent 2 na TCP/10050.
- Monitoring login SQL z uprawnieniami opisanymi niżej.
- `CustomQueriesEnabled=true`.
- Dla E2E: `zabbix_get` dostępny w środowisku wykonującym external check. W testowanym obrazie Docker był dostępny.

## 3. Agent 2 na Windows / SQL Server

### 3.1 Custom queries

Skopiuj wszystkie pliki z `custom-queries/` do:

```text
C:\Program Files\Zabbix Agent 2\Custom Queries\MSSQL
```

Pliki:

- `sqlmaniak_cpu_health.sql`
- `sqlmaniak_db_cpu.sql`
- `sqlmaniak_db_space.sql`
- `sqlmaniak_filegroups.sql`
- `sqlmaniak_io_latency.sql`
- `sqlmaniak_long_transactions.sql`
- `sqlmaniak_tde_status.sql`
- `sqlmaniak_vlf_count.sql`
- `sqlmaniak_e2e.sql`

### 3.2 Konfiguracja custom queries

W konfiguracji pluginu MSSQL ustaw:

```text
Plugins.MSSQL.CustomQueriesEnabled=true
Plugins.MSSQL.CustomQueriesDir=C:\Program Files\Zabbix Agent 2\Custom Queries\MSSQL
```

Gotowy fragment jest w `config/mssql_custom_queries_snippet.conf`.

Po dodaniu lub zmianie pliku SQL:

```powershell
Restart-Service "Zabbix Agent 2"
```

### 3.3 Named session

W środowisku testowym użyto named session:

```text
SQL3
```

Credentials są przechowywane w konfiguracji MSSQL pluginu, dlatego testy działały z pustym user/password:

```powershell
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" `
  -t 'mssql.custom.query[SQL3,,,sqlmaniak_cpu_health]'
```

Test E2E query:

```powershell
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" `
  -t 'mssql.custom.query[SQL3,,,sqlmaniak_e2e]'
```

Oczekiwany wynik:

```json
[{"ok":1,"sql_utc":"2026-09-17T18:52:56.1328646"}]
```

## 4. Uprawnienia SQL

Gotowy skrypt: `sql/01_monitoring_permissions.sql`.

W testowanym środowisku potrzebne były:

### Server level

- `VIEW SERVER STATE` (typowo SQL Server 2016/2019),
- `VIEW SERVER PERFORMANCE STATE` (SQL Server 2022 dla performance-state DMVs),
- `VIEW ANY DEFINITION`,
- `VIEW SERVER SECURITY STATE` — wymagane w teście SQL Server 2022 dla `sys.dm_database_encryption_keys` / TDE.

### msdb

Read na:

- `dbo.sysjobs`
- `dbo.sysjobhistory`
- `dbo.sysjobschedules`

### Każda monitorowana baza użytkownika

Monitoring user:

- `VIEW DATABASE STATE`
- `VIEW DEFINITION`

To było potrzebne m.in. dla DB space i filegroup collectorów. Bez dostępu do bazy `HAS_DBACCESS` było 0 i filegroup query zwracało `null`.

## 5. Makra hosta / template

W testowanym hoście:

```text
{$MSSQL.HOST} = 192.168.50.24
{$MSSQL.PORT} = 1443
{$MSSQL.URI}  = SQL3
```

`{$MSSQL.USER}` / `{$MSSQL.PASSWORD}` nie były ustawione na hoście, ponieważ named session `SQL3` przechowuje credentials w konfiguracji Agent 2.

Dostosuj wartości do własnego hosta.

## 6. Import template

Zaimportuj:

```text
templates/SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly.yaml
```

Po imporcie:

1. Podłącz template do hosta SQL.
2. Sprawdź `Monitoring -> Latest data`.
3. Wymuś `Get database`, jeżeli nowe prototypes nie pojawiły się od razu.
4. `Database discovery` ma heartbeat `5m`.

## 7. External E2E — Docker/Compose

W testowanej instalacji kontener:

```text
zabbix-zabbix-server-1
zabbix/zabbix-server-pgsql:alpine-7.4-latest
```

Katalog external scripts wewnątrz kontenera:

```text
/usr/lib/zabbix/externalscripts
```

Był zamontowany **read-only** z hosta:

```text
/opt/zabbix/zbx_env/usr/lib/zabbix/externalscripts
    -> /usr/lib/zabbix/externalscripts
```

Dlatego skrypt kopiujemy na **hosta**, do źródła bind mount:

```bash
sudo cp sqlmaniak_mssql_e2e.sh \
  /opt/zabbix/zbx_env/usr/lib/zabbix/externalscripts/

sudo chmod 755 \
  /opt/zabbix/zbx_env/usr/lib/zabbix/externalscripts/sqlmaniak_mssql_e2e.sh
```

W repo jest finalna wersja zgodna z Alpine/BusyBox. Nie używa `date +%s%N`, bo w tym obrazie `%N` nie dawało nanosekund. Pomiar korzysta z monotonicznego `/proc/uptime`.

Test wewnątrz kontenera:

```bash
docker exec -it zabbix-zabbix-server-1 \
  /usr/lib/zabbix/externalscripts/sqlmaniak_mssql_e2e.sh \
  192.168.50.24 10050 SQL3
```

Oczekiwany wynik:

```json
{"status":1,"response_ms":10,"zabbix_get_rc":0,"sql_utc":"..."}
```

## 8. Testy collectorów

Przykład:

```powershell
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" `
  -t 'mssql.custom.query[SQL3,,,sqlmaniak_vlf_count]'
```

Do testów kolejnych collectorów zmień ostatni parametr na nazwę pliku bez `.sql`.

## 9. Baseline / anomaly

v1.6 dodaje dla E2E:

- rolling average 1h,
- rolling average 24h,
- MAD 24h,
- anomaly score 24h,
- current / 24h baseline ratio,
- seasonal baseline same hour z 7 dni,
- seasonal deviation z 7 dni.

Pierwsze rolling metrics zaczynają działać szybko. Seasonal metrics wymagają historii z poprzednich dni. **Nie ustawiono jeszcze progów anomaly/latency** — najpierw zbieramy rzeczywisty baseline.

## 10. Ważne ograniczenie capacity

`mssql.db.rows_data.timeleft["{#DBNAME}"]` przewiduje zapełnienie **aktualnie zaalokowanej przestrzeni ROWS**. To nie jest prognoza zapełnienia woluminu / filesystemu. Autogrowth może przesunąć granicę. Osobny filesystem time-to-full pozostaje potencjalnym kolejnym etapem.

## 11. Upgrade

Przy aktualizacji:

1. Zachowaj custom queries i external script.
2. Zaimportuj nowszy YAML z opcją aktualizacji istniejącego template.
3. Sprawdź item prototypes i discovery.
4. Sprawdź `Latest data` dla custom raw items.
5. Nie zmieniaj progów produkcyjnych bez zebranych danych/baseline.
