# Historia zmian

## v1.6 — linia bazowa i anomalie

- średnia krocząca E2E z 1 h i 24 h,
- MAD z 24 h,
- wynik anomalii i współczynnik względem linii bazowej,
- sezonowe funkcje `baselinewma` i `baselinedev`,
- heartbeat reguły wykrywania baz danych ustawiony na 5 minut.

## v1.5.1 — poprawka E2E dla Alpine

- skrypt zewnętrzny używa `/proc/uptime` zamiast `date +%s%N`, dzięki czemu krótki pomiar czasu działa poprawnie w Alpine/BusyBox.

## v1.5 — pełny pomiar E2E

- dodano wartości `raw`, `status`, `response_ms`, `zabbix_get_rc` i `sql_utc`,
- test zewnętrzny jest wykonywany po stronie Zabbix Server/Proxy,
- pomiar obejmuje pełną ścieżkę przez Agent 2, dodatek MSSQL i SQL Server.

## v1.4 — pojemność

- liczba VLF per baza danych i maksimum dla całej instancji,
- prognozowany czas do zapełnienia aktualnie zaalokowanej przestrzeni ROWS.

## v1.3 — stabilizacja wykrywania

- szybsze wykrywanie baz danych,
- stabilniejsze prototypy itemów per baza,
- mapowanie wartości dla TDE.

## v1.2 — pakiet własnych kolektorów

- CPU i schedulery,
- opóźnienia I/O,
- długotrwałe transakcje,
- CPU per baza danych,
- wykorzystanie przestrzeni baz danych,
- filegroupy,
- TDE.
