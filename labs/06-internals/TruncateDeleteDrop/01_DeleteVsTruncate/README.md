# 01 – DELETE vs TRUNCATE

**Cel:** pokazać różnice w logowaniu, ghost records, wydajności i zachowaniu `IDENTITY` oraz triggerów.

## Kroki
1. `01_setup.sql` – przygotowanie tabeli i danych w `tempdb`.
2. `02_delete_demo.sql` – `DELETE TOP (1000)` bez `WHERE`, pokazanie ghost records.
3. `03_check_ghosts.sql` – podgląd `ghost_record_count` vs `record_count` (DMV).
4. `04_truncate_demo.sql` – `TRUNCATE TABLE`, sprawdzenie liczby wierszy i IDENTITY.
5. `99_cleanup.sql` – sprzątanie.

## Odzyskiwanie danych po TRUNCATE – wnioski
- **ROLLBACK w tej samej transakcji** przywraca wszystko.
- Po `COMMIT` odzysk jest **trudny**: log zawiera tylko deallocacje stron; potrzeba analizy loga (np. `fn_dblog`) lub narzędzi zewnętrznych; strony w MDF mogą jeszcze fizycznie leżeć do czasu nadpisania.
