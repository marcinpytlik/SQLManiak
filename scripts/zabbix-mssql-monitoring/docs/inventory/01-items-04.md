# Inwentarz — itemy instancji

Łącznie w szablonie: **139 itemów instancji**.

> Część 4 z 4 — anomalie i sezonowa linia bazowa E2E.

| Nazwa | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| SQLManiak E2E: anomaly score 24h | `mssql.e2e.anomaly.score24h` | item obliczany: `abs(last(//mssql.e2e.response_ms)-avg(//mssql.e2e.response_ms,24h))/(mad(//mssql.e2e.response_ms,24h)+1)` | Odporny na pojedyncze skoki wynik anomalii. Mierzy bezwzględną odległość bieżącego czasu E2E od średniej 24 h i normalizuje ją przez `MAD + 1`. W v1.6 ma charakter informacyjny; nie ma jeszcze aktywnego progu triggera. |
| SQLManiak E2E: current vs 24h baseline ratio | `mssql.e2e.baseline.ratio24h` | item obliczany: `last(//mssql.e2e.response_ms)/(avg(//mssql.e2e.response_ms,24h)+1)` | Stosunek bieżącego czasu odpowiedzi E2E do średniej kroczącej z 24 h. Wartość około `1.0` oznacza zachowanie zbliżone do linii bazowej, a wartość powyżej `1.0` oznacza odpowiedź wolniejszą od średniej. |
| SQLManiak E2E: seasonal baseline same hour 7d | `mssql.e2e.baseline.seasonal7d` | item obliczany: `baselinewma(//mssql.e2e.response_ms,1h:now/h,"d",7)` | Sezonowa linia bazowa wykorzystująca `baselinewma()`. Porównuje tę samą pełną godzinę dnia z siedmiu poprzednich dni. Wymaga odpowiednio długiej historii trendów, więc po instalacji potrzebuje okresu rozgrzewki. |
| SQLManiak E2E: seasonal deviation same hour 7d | `mssql.e2e.anomaly.seasonaldev7d` | item obliczany: `baselinedev(//mssql.e2e.response_ms,1h:now/h,"d",7)` | Sezonowe odchylenie wyliczane przez `baselinedev()`. Pokazuje, o ile jednostek odchylenia standardowego poprzednia pełna godzina różni się od tej samej godziny w poprzednich siedmiu dniach. W v1.6 jest informacyjne i nie ma własnego triggera. |
