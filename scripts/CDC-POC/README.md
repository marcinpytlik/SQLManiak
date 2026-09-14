# SQL Server CDC + Debezium + Kafka — POC

Ten POC jest prowadzony etapami, tak aby każdy krok miał jasno określony cel, sposób uruchomienia, kryterium PASS/FAIL i możliwość powrotu do poprzedniego stanu.

## Architektura

```text
Application / DML
      |
      v
SQL Server transaction log
      |
      v
SQL Server CDC capture job
      |
      v
cdc.*_CT
      |
      v
Debezium SQL Server Connector
      |
      v
Kafka topic
      |
      v
Consumer
```

## Etapy POC

| Stage | Cel | Wynik |
|---|---|---|
| 1 | przygotowanie SQL Server i natywnego CDC | działające capture instances i dane w `cdc.*_CT` |
| 2 | integracja Debezium + Kafka | connector i task w stanie `RUNNING` |
| 3 | test end-to-end | INSERT/UPDATE/DELETE widoczne w Kafka |
| 4 | testy odporności | restart, backlog, rollback, retention, schema evolution |
| 5 | production readiness | monitoring, security, HA, capacity, runbook i decyzja GO/NO-GO |

Dokładna kolejność znajduje się w `POC_Runbook.md`.

## Stage 1 — SQL Server CDC

Uruchom kolejno:

```text
00_CreateDatabase.sql
01_CreateTables.sql
02_EnableCDC.sql
03_GenerateData.sql
04_ReadChanges.sql
05_CDC_Monitoring.sql
06_CDC_Retention.sql
```

Baza `CDC_Lab` posiada dedykowany filegroup `CDC_CT` dla change tables CDC.

Kryterium PASS:

- `CDC_Lab.is_cdc_enabled = 1`,
- `dbo.Customer` i `dbo.CustomerOrder` są śledzone,
- `cdc.CDC_Lab_capture` działa,
- zmiany pojawiają się w `cdc.dbo_Customer_CT` i `cdc.dbo_CustomerOrder_CT`,
- `cdc.change_tables.filegroup_name = CDC_CT`.

## Stage 2 — Debezium + Kafka

Przejdź do:

```powershell
cd .\Debezium
```

Uruchom:

```text
00_CreateDebeziumLogin.sql
01_Start.ps1
02_RegisterConnector.ps1
03_Status.ps1
04_ListTopics.ps1
```

Kryterium PASS:

```text
connector = RUNNING
task      = RUNNING
```

## Stage 3 — End-to-end

W jednym oknie PowerShell:

```powershell
.\05_Consume.ps1 -FromBeginning
```

W SSMS:

```text
06_TestChanges.sql
```

Spodziewane operacje Debezium:

```text
r = snapshot/read
c = create
u = update
d = delete
```

Kryterium PASS: zmiany wykonane w SQL Server pojawiają się w topicach Kafka.

## Stage 4 — odporność i recovery

Testy znajdują się w katalogu `Tests`.

Zakres:

- restart Kafka Connect,
- restart Kafka,
- restart SQL Server,
- backlog recovery,
- rollback transakcji,
- schema evolution,
- retention / LSN gap,
- ordering / duplicate delivery,
- operational checks.

Test `07_RetentionGap.sql` jest LAB-ONLY.

## Stage 5 — Production Readiness

Stage 5 nie oznacza automatycznie wdrożenia produkcyjnego. Jego celem jest zebranie dowodów, że rozwiązanie można bezpiecznie pilotować.

Obszary:

- monitoring i alerting,
- bezpieczeństwo i minimalne uprawnienia,
- TLS / secrets,
- HA / failover,
- capacity planning,
- retention i maksymalny dopuszczalny backlog,
- schema governance,
- runbook operacyjny,
- kryteria GO / NO-GO.

Szczegóły: `Stages/Stage-05-Production-Readiness.md`.

## Dokumentacja

- `POC_Runbook.md` — pełna kolejność wykonania POC,
- `CDC_Requirements_and_Limitations.md` — wymagania i ograniczenia CDC,
- `CDC_Operational_Runbook.md` — operacje administracyjne,
- `CDC_Troubleshooting.md` — diagnostyka warstwa po warstwie,
- `Architecture/ADR-001-CDC-Debezium-Kafka.md` — decyzja architektoniczna,
- `Architecture/Connector-Offsets-Retry.md` — szczegółowo: connector, offsety, retry i recovery,
- `Tests/README.md` — matryca testów odporności,
- `PROMPTER.md` — kolejność i scenariusz do nagrania/demo.

## Cleanup

SQL Server:

```text
99_Cleanup.sql
```

Debezium/Kafka:

```powershell
cd .\Debezium
.\99_StopAndCleanup.ps1
```

Pełna kolejność cleanupu jest opisana w `POC_Runbook.md`.

## Definicja sukcesu POC

POC jest zakończony sukcesem dopiero wtedy, gdy:

1. Stage 1–3 przechodzą poprawnie,
2. testy Stage 4 mają udokumentowany wynik,
3. potrafimy wykryć zatrzymany `cdc.CDC_Lab_capture`,
4. potrafimy wznowić Debezium bez utraty zmian znajdujących się jeszcze w retencji CDC,
5. znamy procedurę dla utraty LSN,
6. znamy procedurę dla zmiany schematu,
7. Stage 5 kończy się świadomą decyzją GO/NO-GO do pilotażu.
