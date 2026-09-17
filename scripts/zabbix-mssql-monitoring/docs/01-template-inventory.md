# Pełny inwentarz szablonu SQLManiak MSSQL by Zabbix Agent 2

Wersja: **v1.6 — linia bazowa i anomalie**, Zabbix **7.4**.

Ten dokument jest punktem wejścia do pełnego inwentarza. Szczegółowe listy zostały rozdzielone na mniejsze pliki, żeby wygodnie czytało się je w GitHubie i VS Code.

> **Uwaga:** nazwy itemów, klucze Zabbixa, nazwy makr i nazwy liczników pozostają zgodne z rzeczywistym szablonem. Opisy, nagłówki i objaśnienia są po polsku.

## 1. Itemy instancji

Łącznie: **139**.

- [część 1 — podstawowe liczniki instancji](inventory/01-items-01.md)
- [część 2 — pamięć, blokady, transakcje i pozostałe liczniki](inventory/01-items-02.md)
- [część 3 — kolektory SQLManiak, CPU, I/O, E2E i linia bazowa](inventory/01-items-03.md)
- [część 4 — anomalie i sezonowa linia bazowa](inventory/01-items-04.md)

## 2. Reguły wykrywania i prototypy itemów

Łącznie: **10 reguł wykrywania** i **75 prototypów itemów**.

- [część 1 — Availability Groups, bazy, joby, local DB i mirroring](inventory/02-prototypes-01.md)
- [część 2 — non-local DB, quorum, repliki i filegroupy](inventory/02-prototypes-02.md)

## 3. Triggery i prototypy triggerów

Łącznie: **76**.

- [część 1](inventory/03-triggers-01.md)
- [część 2](inventory/03-triggers-02.md)
- [część 3](inventory/03-triggers-03.md)

## 4. Makra

Łącznie: **64**.

- [pełna lista makr](inventory/04-macros.md)

## 5. Mechanizmy zbierania danych

| Mechanizm | Jak działa |
|---|---|
| **Zabbix Agent 2 + dodatek MSSQL** | natywne klucze `mssql.*` odpytywane przez Agent 2 |
| **Własne zapytanie SQL** | pliki `.sql` wywoływane przez `mssql.custom.query[...]` |
| **Item zależny** | wartość wyciągana z itemu nadrzędnego przez preprocessing, bez dodatkowego połączenia do SQL Server |
| **Item obliczany** | wynik obliczany na podstawie historii Zabbixa, np. rate, ratio, `timeleft`, linia bazowa lub wynik anomalii |
| **Prosty test** | test TCP dostępności portu lub czasu zestawienia połączenia |
| **Test zewnętrzny** | pełny pomiar E2E wykonywany przez Zabbix Server/Proxy: `zabbix_get → Agent 2 → dodatek MSSQL → SQL Server → odpowiedź` |

## 6. Najważniejsze rozszerzenia SQLManiak

Rozszerzenia dodane ponad standardowy szablon obejmują:

- CPU i presję na schedulerach,
- względne wykorzystanie CPU,
- CPU per baza danych,
- opóźnienia I/O,
- aktywne i długotrwałe transakcje,
- przestrzeń danych ROWS,
- filegroupy,
- TDE,
- VLF,
- E2E,
- kroczące linie bazowe,
- sezonową linię bazową,
- miary anomalii.

## 7. Zasada interpretacji

Inwentarz opisuje **co zbieramy i w jaki sposób**. Nie każda metryka ma własny trigger. Część danych służy do korelacji, dashboardów albo budowania kontekstu diagnostycznego.

Przykładowo wysoka wartość pojedynczego licznika nie musi oznaczać awarii. Dlatego blokady korelujemy z czasem oczekiwania i timeoutami, a CPU interpretujemy razem z presją na schedulerach i liczbą schedulerów dostępnych dla SQL Server.
