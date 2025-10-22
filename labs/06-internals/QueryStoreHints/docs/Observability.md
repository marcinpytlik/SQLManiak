# Obserwacja efektu Query Store Hints – przed/po

Ten moduł pomaga **zmierzyć efekt** nałożonego hinta: porównuje metryki *przed* i *po* oraz rysuje timeline po bucketach Query Store.

## Skrypty
- `QSH_Compare_BeforeAfter_ByHint.sql` – automatycznie wyznacza moment zmiany (ostatnie `last_modified` z `sys.query_store_query_hints`) i liczy agregaty przed/po.
- `QSH_Timeline_PerInterval.sql` – seria czasowa (per `sys.query_store_runtime_stats_interval`) dla CPU/czasu/reads.

## Jak używać
1. Ustal `@query_id` (np. `QSH_Find_Query_ByText.sql`).
2. (Opcjonalnie) zawęź zakres dat `@from`/`@to`. Bez tego skrypt obejmie cały horyzont Query Store.
3. Najpierw uruchom `QSH_Compare_BeforeAfter_ByHint.sql`, potem `QSH_Timeline_PerInterval.sql`.
4. Szukaj spadku **avg/total duration**, **CPU**, **logical_reads** po stronie „After”.

> Uwaga: Query Store liczy czasy w mikrosekundach. W skryptach przeliczam na **ms** dla czytelności.
