# Pełny inwentarz szablonu SQLManiak MSSQL by Zabbix agent 2

Wersja: **v1.6 baseline/anomaly**, Zabbix **7.4**.

Pełny inwentarz został rozdzielony na cztery pliki, żeby był czytelny w GitHubie:

- [Items instancji](inventory/01-items.md)
- [Discovery i item prototypes](inventory/02-discovery-prototypes.md)
- [Triggery i trigger prototypes](inventory/03-triggers.md)
- [Makra](inventory/04-macros.md)

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
