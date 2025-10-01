# Runbook — Sliding Window Partitioning
**Cel:** Przesuwne okno danych: dodaj nową partycję na początek, odłącz najstarszą do archiwum.

## Kroki
1. Przygotuj **staging table** o identycznej definicji (schemat, indeksy) na właściwej filegroupie.
2. Załaduj dane do staginga (bulk insert).
3. `ALTER PARTITION FUNCTION` — rozszczep granicę (SPLIT RANGE) dla nowego przedziału.
4. `ALTER TABLE ... SWITCH PARTITION` — przełącz staging → produkcja (O(1)).
5. Najstarszą partycję `SWITCH` do tabeli tymczasowej i `ALTER PARTITION FUNCTION` — `MERGE RANGE`.
6. Odtwórz statystyki dla nowych partycji (incremental).

## Uwagi
- Upewnij się, że CHECK constraints i kolacja są identyczne.
- W Query Store wyklucz duże, rzadkie batch'e ETL z capture (capture policy).