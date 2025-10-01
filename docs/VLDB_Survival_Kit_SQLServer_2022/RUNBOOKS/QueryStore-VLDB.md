# Runbook — Query Store dla VLDB
**Cel:** Zbieranie planów/zapytań bez wysadzenia tempdb i dysku.

## Zalecenia
- Capture Mode: AUTO (czasem MANUAL + sp_executesql dla krytyków).
- Max Size: w granicach 10–50 GB, w zależności od retencji.
- Staggered cleanup job co noc, ograniczanie do 7–14 dni dla OLTP VLDB.
- Włącz **wait stats** capture (SQL 2022 rozszerzenia).

## Kroki
1. Uruchom `SCRIPTS/TSQL/20_querystore_vldb.sql`.
2. Ustaw retencję, rozmiary, interwały flush.
3. Dodaj alert na osiągnięcie 80% pojemności QS.
