# Ghost Records Demo (SQL Server)

Ghost records to wiersze usunięte logicznie (oznaczone jako GHOST) na stronie danych B-Tree.
Fizycznie pozostają na stronie do czasu sprzątnięcia przez *Ghost Cleanup Task* lub operacje
defragmentacyjne (np. `ALTER INDEX ... REORGANIZE`). Dzięki temu DELETE jest szybki, a sprzątanie
może odbywać się asynchronicznie.

## Co w paczce
- `ghost_demo.sql` – tworzy tabelę, generuje ghosty, pokazuje strony i PageLSN.
- `dmvs.sql` – zapytania DMV do podejrzenia liczby ghostów i operacji na indeksie.
- `cleanup.sql` – wymusza sprzątanie ghostów i ponownie pokazuje metryki.

## Szybki przebieg
1. Uruchom `ghost_demo.sql` – zobaczysz INSERT/DELETE i narzędzia diagnostyczne:
   - `sys.dm_db_index_physical_stats` → kol. `ghost_record_count`, `avg_page_space_used_in_percent`,
   - `sys.dm_db_index_operational_stats` → liczniki operacyjne,
   - `DBCC IND` i `DBCC PAGE` (z TF 3604) → podgląd flag GHOST na stronach.
2. Uruchom `dmvs.sql` – snapshot metryk.
3. Uruchom `cleanup.sql` – `DBCC FORCEGHOSTCLEANUP` w bieżącej bazie; metryki po sprzątnięciu.

> Uwaga: Ghosty tworzą się zarówno przy `DELETE`, jak i przy niektórych `UPDATE` powodujących relokację
> wiersza. W wersjonowaniu (SI/RCSI) dodatkowo zobaczysz `version_ghost_record_count`.
