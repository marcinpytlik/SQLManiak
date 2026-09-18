# Instalacja SQLManiak MSSQL w Zabbix 7.4

Dokument odtwarza konfigurację, którą faktycznie uruchomiliśmy i przetestowaliśmy w laboratorium.

## 1. Architektura

Podstawowy tor monitoringu:

```text
Zabbix Server 7.4 (Docker Compose)
        |
        | standardowe itemy + test E2E
        v
Zabbix Agent 2 (Windows, SQL64)
        |
        | dodatek MSSQL, nazwana sesja SQL3
        v
SQL Server — nazwana instancja SQL3
```

Pełny pomiar E2E:

```text
kontener Zabbix Server
 -> skrypt zewnętrzny
 -> zabbix_get
 -> Agent 2 :10050
 -> dodatek MSSQL
 -> SQL3
 -> sqlmaniak_e2e.sql
 -> odpowiedź
```

## 2. Wymagania

- Zabbix Server 7.4,
- Zabbix Agent 2 z dodatkiem MSSQL 7.4 na serwerze SQL,
- łączność Zabbix Server/Proxy → Agent 2 na TCP/10050,
- login SQL do monitoringu z uprawnieniami opisanymi w dalszej części,
- włączone własne zapytania MSSQL: `CustomQueriesEnabled=true`,
- dla E2E: polecenie `zabbix_get` dostępne w środowisku wykonującym test zewnętrzny.

W testowanym obrazie Docker `zabbix_get` był dostępny w kontenerze Zabbix Server.

## 3. Zabbix Agent 2 na Windows / SQL Server

### 3.1. Własne zapytania SQL

Skopiuj wszystkie pliki z katalogu repozytorium:

```text
custom-queries/
```

do katalogu Zabbix Agent 2:

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

### 3.2. Włączenie własnych zapytań

W konfiguracji dodatku MSSQL ustaw:

```text
Plugins.MSSQL.CustomQueriesEnabled=true
Plugins.MSSQL.CustomQueriesDir=C:\Program Files\Zabbix Agent 2\Custom Queries\MSSQL
```

Gotowy fragment konfiguracji znajduje się w:

```text
config/mssql_custom_queries_snippet.conf
```

Po dodaniu albo zmianie dowolnego pliku SQL zrestartuj Agent 2:

```powershell
Restart-Service "Zabbix Agent 2"
```

### 3.3. Nazwana sesja MSSQL

W środowisku testowym użyliśmy nazwanej sesji:

```text
SQL3
```

Dane logowania są przechowywane w konfiguracji dodatku MSSQL, dlatego podczas testów można było pozostawić parametry użytkownika i hasła puste.

Przykład testu kolektora CPU:

```powershell
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" `
  -t 'mssql.custom.query[SQL3,,,sqlmaniak_cpu_health]'
```

Test zapytania E2E:

```powershell
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" `
  -t 'mssql.custom.query[SQL3,,,sqlmaniak_e2e]'
```

Przykładowy poprawny wynik:

```json
[{"ok":1,"sql_utc":"2026-09-17T18:52:56.1328646"}]
```

## 4. Uprawnienia SQL Server

Gotowy skrypt znajduje się w:

```text
sql/01_monitoring_permissions.sql
```

Zakres wymaganych uprawnień zależy od wersji SQL Server i używanych kolektorów.

### 4.1. Poziom serwera

W testowanym środowisku potrzebne były:

- `VIEW SERVER STATE` — typowo SQL Server 2016/2019,
- `VIEW SERVER PERFORMANCE STATE` — SQL Server 2022 dla części DMV związanych z wydajnością,
- `VIEW ANY DEFINITION`,
- `VIEW SERVER SECURITY STATE` — wymagane w naszym teście SQL Server 2022 dla `sys.dm_database_encryption_keys` i monitoringu TDE.

### 4.2. Baza `msdb`

Login monitoringu potrzebuje odczytu informacji o jobach SQL Server Agent, m.in. z:

- `dbo.sysjobs`,
- `dbo.sysjobhistory`,
- `dbo.sysjobschedules`.

### 4.3. Każda monitorowana baza użytkownika

W każdej bazie użytkownika konto monitoringu powinno mieć użytkownika bazy oraz:

- `VIEW DATABASE STATE`,
- `VIEW DEFINITION`.

Było to potrzebne m.in. dla kolektorów przestrzeni bazy i filegroupów. Bez dostępu do bazy `HAS_DBACCESS` zwracało `0`, a zapytanie filegroupów zwracało `null`.

## 5. Makra hosta i szablonu

W testowanym hoście ustawiono:

```text
{$MSSQL.HOST} = 192.168.50.24
{$MSSQL.PORT} = 1443
{$MSSQL.URI}  = SQL3
```

Makra:

```text
{$MSSQL.USER}
{$MSSQL.PASSWORD}
```

nie były ustawione na hoście, ponieważ dane logowania przechowuje nazwana sesja `SQL3` w konfiguracji Zabbix Agent 2.

Dostosuj host, port i nazwę sesji do własnego środowiska.

## 6. Odbudowanie pliku YAML szablonu

W repozytorium pełny YAML jest zapisany jako pięć skompresowanych fragmentów. Najpierw odbuduj plik.

### Linux

```bash
cd scripts/zabbix-mssql-monitoring/templates
sh rebuild-template.sh
```

### Windows / PowerShell

```powershell
Set-Location scripts\zabbix-mssql-monitoring\templates
.\rebuild-template.ps1
```

Powstanie plik:

```text
SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly.yaml
```

Oczekiwana suma SHA256:

```text
2b47546f54ad8e9aaa78fb1ebec7b7f51ab044d137abedc6a0bf041cf500f40d
```

Skrypty odbudowujące automatycznie sprawdzają tę sumę.

## 7. Import szablonu do Zabbixa

Zaimportuj plik:

```text
templates/SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly.yaml
```

Po imporcie:

1. Podłącz szablon do hosta SQL Server.
2. Ustaw wymagane makra hosta.
3. Otwórz `Monitoring → Latest data` i sprawdź, czy pojawiają się dane.
4. Jeżeli nowe prototypy baz danych nie pojawiły się od razu, wymuś wykonanie itemu `Get database` i reguły `Database discovery`.
5. `Database discovery` ma heartbeat ustawiony na `5m`.

## 8. Pełny pomiar E2E — Docker Compose

W testowanej instalacji Zabbix Server działał w kontenerze:

```text
zabbix-zabbix-server-1
```

na obrazie:

```text
zabbix/zabbix-server-pgsql:alpine-7.4-latest
```

### 8.1. Katalog skryptów zewnętrznych

Wewnątrz kontenera:

```text
/usr/lib/zabbix/externalscripts
```

Katalog był zamontowany tylko do odczytu z hosta:

```text
/opt/zabbix/zbx_env/usr/lib/zabbix/externalscripts
    -> /usr/lib/zabbix/externalscripts
```

Dlatego skrypt trzeba skopiować do katalogu źródłowego bind mounta na hoście, a nie bezpośrednio do kontenera.

Przykład:

```bash
sudo cp external-scripts/sqlmaniak_mssql_e2e.sh \
  /opt/zabbix/zbx_env/usr/lib/zabbix/externalscripts/

sudo chmod 755 \
  /opt/zabbix/zbx_env/usr/lib/zabbix/externalscripts/sqlmaniak_mssql_e2e.sh
```

### 8.2. Dlaczego skrypt używa `/proc/uptime`

Finalna wersja skryptu jest zgodna z Alpine/BusyBox. Nie używa:

```bash
date +%s%N
```

ponieważ w użytym obrazie `%N` nie zwracało nanosekund. W rezultacie krótki pomiar E2E potrafił zwracać `0 ms`.

Czas mierzony jest z użyciem monotonicznego zegara:

```text
/proc/uptime
```

### 8.3. Test z wnętrza kontenera

```bash
docker exec -it zabbix-zabbix-server-1 \
  /usr/lib/zabbix/externalscripts/sqlmaniak_mssql_e2e.sh \
  192.168.50.24 10050 SQL3
```

Przykładowy poprawny wynik:

```json
{"status":1,"response_ms":10,"zabbix_get_rc":0,"sql_utc":"..."}
```

Interpretacja:

- `status = 1` — pełna ścieżka E2E działa,
- `response_ms` — całkowity czas przejścia przez cały tor,
- `zabbix_get_rc = 0` — `zabbix_get` zakończył się sukcesem,
- `sql_utc` — znacznik czasu zwrócony przez SQL Server.

## 9. Testowanie własnych kolektorów

Przykład dla VLF:

```powershell
& "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe" `
  -t 'mssql.custom.query[SQL3,,,sqlmaniak_vlf_count]'
```

Dla kolejnych kolektorów zmień ostatni parametr na nazwę odpowiedniego pliku bez rozszerzenia `.sql`.

## 10. Linia bazowa i anomalie E2E

Wersja v1.6 dodaje:

- średnią kroczącą 1 h,
- średnią kroczącą 24 h,
- MAD z 24 h,
- wynik anomalii z 24 h,
- współczynnik bieżącej wartości do linii bazowej 24 h,
- sezonową linię bazową dla tej samej godziny dnia z siedmiu poprzednich dni,
- sezonowe odchylenie dla tej samej godziny dnia.

Metryki kroczące zaczynają działać szybko, natomiast metryki sezonowe wymagają historii z poprzednich dni.

**W wersji v1.6 nie ustawiliśmy jeszcze progów alarmowych dla anomalii i opóźnienia E2E.** Najpierw zbieramy rzeczywiste dane bazowe.

## 11. Ważne ograniczenie prognozy pojemności

Item:

```text
mssql.db.rows_data.timeleft["{#DBNAME}"]
```

przewiduje czas do zapełnienia **aktualnie zaalokowanej przestrzeni ROWS**.

Nie jest to prognoza zapełnienia całego woluminu lub filesystemu. Autogrowth może zwiększyć rozmiar plików i przesunąć moment faktycznego braku przestrzeni.

Osobny monitoring czasu do zapełnienia filesystemu pozostaje możliwym kolejnym etapem.

## 12. Aktualizacja do nowszej wersji

Przy aktualizacji szablonu:

1. Zachowaj własne zapytania SQL oraz skrypt E2E.
2. Odbuduj i zaimportuj nowszy plik YAML z opcją aktualizacji istniejącego szablonu.
3. Sprawdź reguły wykrywania i prototypy itemów.
4. Sprawdź `Latest data` dla własnych itemów `raw`.
5. Zweryfikuj, czy własne makra hosta nie zostały nadpisane.
6. Nie zmieniaj progów produkcyjnych bez danych historycznych i zebranej linii bazowej.

## 13. Szybka lista kontrolna

Po zakończeniu instalacji potwierdź:

- [ ] Agent 2 odpowiada na porcie 10050,
- [ ] dodatek MSSQL łączy się do właściwej instancji,
- [ ] własne zapytania są w poprawnym katalogu,
- [ ] `CustomQueriesEnabled=true`,
- [ ] monitoring login ma wymagane uprawnienia,
- [ ] import szablonu zakończył się bez błędów,
- [ ] discovery baz utworzyło itemy per baza,
- [ ] kolektory CPU, I/O, filegroups, TDE i VLF zwracają dane,
- [ ] skrypt E2E działa z poziomu Zabbix Server/Proxy,
- [ ] `SQLManiak E2E: response time` zapisuje wartości większe od zera,
- [ ] linia bazowa E2E zaczęła się budować.
