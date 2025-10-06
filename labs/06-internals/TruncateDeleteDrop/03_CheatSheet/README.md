# 03 – Cheat-Sheet: DELETE vs TRUNCATE vs DROP

| Cecha | DELETE | TRUNCATE | DROP |
|---|---|---|---|
| Co usuwa? | Wiersze (`WHERE`) | Wszystkie wiersze | Całą tabelę (dane+schemat) |
| Struktura | Zostaje | Zostaje | Znika |
| Logowanie | Pełne (rekordy) | Minimalne (deallocacje stron) | Metadane |
| Ghost records | Tak | Nie | N/D |
| Filtr | Tak | Nie | Nie |
| RESET IDENTITY | Nie | Tak | N/D |
| Triggery | Uruchamia | Nie uruchamia | N/D |
| Wydajność | Wolniej przy masie | Bardzo szybkie | Bardzo szybkie |
| Odzysk | Łatwiejszy | Trudny | Backup/log |
