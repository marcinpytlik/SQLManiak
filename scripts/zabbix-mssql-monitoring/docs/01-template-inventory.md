# Pełny inwentarz szablonu SQLManiak MSSQL by Zabbix agent 2

Wersja: **v1.6 baseline/anomaly**, Zabbix **7.4**.

Pełny inwentarz został rozdzielony na mniejsze pliki, żeby był czytelny w GitHubie:

### Items instancji
- [część 1](inventory/01-items-01.md)
- [część 2](inventory/01-items-02.md)
- [część 3 — collectory SQLManiak, E2E i baseline](inventory/01-items-03.md)
- [część 4 — anomaly/seasonal](inventory/01-items-04.md)

### Discovery i item prototypes
- [część 1 — AG, DB, jobs, local DB, mirroring](inventory/02-prototypes-01.md)
- [część 2 — non-local DB, quorum, replicas, filegroups](inventory/02-prototypes-02.md)

### Triggery i trigger prototypes
- [część 1](inventory/03-triggers-01.md)
- [część 2](inventory/03-triggers-02.md)
- [część 3](inventory/03-triggers-03.md)

### Makra
- [pełna lista makr](inventory/04-macros.md)

## Liczby

- Items instancji: **139**
- Discovery rules: **10**
- Item prototypes: **75**
- Makra: **64**
- Triggery / trigger prototypes: **76**

## Jak mierzymy

- **Agent 2 MSSQL plugin** — natywne klucze `mssql.*`.
- **Custom query** — pliki SQL wywoływane przez `mssql.custom.query[...]`.
- **Dependent item** — preprocessing z master itemu, bez dodatkowego połączenia do SQL.
- **Calculated item** — obliczenia na historii Zabbixa (`rate`, ratio, `timeleft`, baseline/anomaly).
- **Simple check** — TCP availability / connection time.
- **External check** — pełny E2E wykonywany na Zabbix Server/Proxy: `zabbix_get → Agent 2 → MSSQL plugin → SQL → return`.

## Najważniejsze rozszerzenia SQLManiak

CPU/scheduler, CPU per DB, I/O latency, long transactions, DB ROWS capacity, filegroups, TDE, VLF, E2E oraz rolling/seasonal baseline-anomaly.
