# Mapowanie arkusza Excel na aktualny szablon Zabbixa

**Źródło wymagań:** `MSSQL_alerty_Grafana_macierz_v6_complete_CPU_SQL(2).xlsx`  
**Docelowa implementacja:** SQLManiak MSSQL **v1.6 — linia bazowa i anomalie**.

Ten dokument pokazuje, jak pozycje z pierwotnej macierzy alertów zostały odwzorowane w aktualnym szablonie Zabbixa.

## Legenda

| Oznaczenie | Znaczenie |
|---|---|
| ✅ | element został zaimplementowany |
| 🟡 | metryka istnieje, ale implementacja jest częściowa albo docelowy trigger został świadomie odłożony |
| 🔁 | pierwotny sposób pomiaru został zastąpiony innym rozwiązaniem |
| ⏳ | element nie został jeszcze zaimplementowany |

## Szczegółowe mapowanie

Ze względu na rozmiar macierzy zestawienie zostało podzielone na trzy części:

- [Macierz alertów — pozycje 1–49](excel-mapping/01-macierz-01-49.md)
- [Macierz alertów — pozycje 50–82](excel-mapping/02-macierz-50-82.md)
- [Alerty per instancja, per baza oraz CPU per baza](excel-mapping/03-alerts-and-cpu.md)

## Najważniejsze różnice względem pierwotnej macierzy

### ODBC

Pierwotne odpytywanie przez ODBC zostało zastąpione przez **Zabbix Agent 2 z dodatkiem MSSQL** oraz własne zapytania `mssql.custom.query[...]`.

Dzięki temu logika monitoringu jest bliższa oficjalnemu sposobowi integracji Zabbixa z SQL Serverem i nie wymaga osobnego stosu ODBC dla większości metryk.

### E2E

Pomiar E2E został rozszerzony do pełnej ścieżki:

```text
Zabbix Server/Proxy
    → zabbix_get
    → Zabbix Agent 2
    → dodatek MSSQL
    → SQL Server
    → własne zapytanie sqlmaniak_e2e
    → odpowiedź
```

Mierzymy zarówno poprawność całego toru, jak i jego rzeczywisty czas odpowiedzi.

### CPU

Monitoring CPU został rozszerzony o:

- liczbę logicznych CPU hosta,
- liczbę schedulerów SQL Server w stanie `VISIBLE ONLINE`,
- liczbę zadań oczekujących na scheduler,
- zadania uruchamialne per aktywny scheduler,
- kolejkę pracy schedulerów,
- `SOS_SCHEDULER_YIELD`,
- rozdzielenie CPU SQL Server / system idle / inne procesy,
- względne wykorzystanie CPU znormalizowane do schedulerów dostępnych dla SQL Server,
- CPU per baza danych.

### Pojemność

Monitoring pojemności został rozszerzony o:

- wykorzystanie przestrzeni ROWS per baza,
- filegroupy,
- liczbę VLF per baza,
- maksymalną liczbę VLF na instancji,
- prognozę czasu do zapełnienia aktualnie zaalokowanej przestrzeni ROWS.

> Prognoza ROWS nie jest prognozą zapełnienia całego filesystemu. Autogrowth może zwiększyć dostępną przestrzeń danych.

### Linia bazowa i anomalie

Wersja v1.6 dodaje dla E2E:

- średnią kroczącą 1 h,
- średnią kroczącą 24 h,
- MAD z 24 h,
- wynik anomalii 24 h,
- współczynnik bieżącej wartości do linii bazowej 24 h,
- sezonową linię bazową dla tej samej godziny dnia z siedmiu poprzednich dni,
- sezonowe odchylenie od typowego zachowania.

Anomalie CPU per baza pozostają potencjalnym kolejnym etapem.

## Świadomie odłożone progi

Część triggerów progowych dla I/O, pojemności i anomalii została celowo pozostawiona bez aktywnych progów. Najpierw zbieramy rzeczywiste dane z monitorowanych instancji, a dopiero później dobieramy wartości ostrzegawcze i krytyczne.

Dzięki temu unikamy alertów opartych na arbitralnych wartościach, które nie odzwierciedlają charakterystyki konkretnego środowiska.
