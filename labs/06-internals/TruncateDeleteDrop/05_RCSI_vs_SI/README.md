# 05 – RCSI vs SNAPSHOT ISOLATION: wersjonowanie i wpływ na DELETE/TRUNCATE

**Cel:** zobaczyć jak włączenie READ_COMMITTED_SNAPSHOT (RCSI) i SNAPSHOT ISOLATION (SI) wpływa na blokady, waity i zużycie version store.

## Kroki
1. `01_prep_db.sql` – tworzy `DemoVersioning`, włącza RCSI i SI, tworzy tabelę i dane.
2. `02_reader_rcsi.sql` – czytelnik w `READ COMMITTED` (RCSI działa transparentnie).
3. `03_reader_snapshot.sql` – czytelnik w `SNAPSHOT`.
4. `04_writer_delete.sql` – jednoczesny `DELETE` z otwartą transakcją (obserwuj blokady i version store).
5. `05_truncate.sql` – `TRUNCATE TABLE` (zwróć uwagę na `Sch-M` oraz na to, że nie generuje wersji).
6. `06_dmvs.sql` – `sys.dm_tran_version_store_space_usage`, `sys.dm_tran_active_snapshot_database_transactions`, podstawowe waity.

**Uwaga:** RCSI/SI może zwiększać zużycie tempdb (version store) – monitoruj!
