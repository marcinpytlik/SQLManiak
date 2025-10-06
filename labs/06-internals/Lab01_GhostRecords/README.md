# Lab 01 — Ghost Records (SQL Server Internals)

Ten lab pokazuje **ghost records**: jak powstają, jak je zobaczyć na stronach danych oraz jak (i kiedy) są sprzątane przez **Ghost Cleanup**.

> **Bezpieczeństwo:** Lab zakłada **SQL Server 2022 Developer** na środowisku testowym. Nie rób tego na produkcji. Niektóre kroki (np. trace flag 661) mają **globalny** wpływ na instancję.

## Cel
- Wygenerować ghost records przez `DELETE`.
- Zobaczyć je w DMV: `sys.dm_db_index_physical_stats`, `sys.dm_db_index_operational_stats`.
- Zajrzeć do stron danych (`DBCC IND`, `DBCC PAGE`) i potwierdzić oznaczenie rekordów jako ghost.
- Zaobserwować ich usunięcie po **REORGANIZE/REBUILD** lub przez background Ghost Cleanup.

## Wymagania
- SQL Server 2022 (Developer).
- Uprawnienia sysadmin (DBCC PAGE/IND).
- VS Code (preferowane) + rozszerzenie `ms-mssql.mssql` **lub** `sqlcmd` 19.x.
- Konto z uprawnieniami do tworzenia bazy.

## Szybki start (VS Code)
1. Otwórz folder `Lab01_GhostRecords` w VS Code.
2. Ustaw połączenie do instancji (Command Palette → `MS SQL: Connect`).
3. Uruchom w kolejności:
   - `scripts/01_setup.sql`
   - `scripts/02_demo_ghosts.sql`
   - `scripts/03_cleanup.sql` (opcjonalnie, sprzątanie)
4. Alternatywnie: Tasks → `Run Task…` → wybierz krok (wymaga `sqlcmd` i uzupełnienia zmiennych w `tasks.json`).

---

## Plan eksperymentu

### 1) Tworzymy bazę i tabelę z klastrem
- Baza: `GhostLabDB`
- Tabela: `dbo.GhostLab (Id INT IDENTITY, Payload CHAR(400) …)`
- Klaster: `PK_GhostLab_Id` na kolumnie `Id`

### 2) Wstawiamy porcje danych i notujemy lokalizację
- `INSERT` 50 000 wierszy z deterministycznym `Payload`.
- Używamy `%%physloc%%` + `sys.fn_PhysLocCracker` aby złapać `File:Page:Slot`.
- Sprawdzamy strony przypisane do indeksu: `DBCC IND`.

### 3) Usuwamy część wierszy → powstają ghosty
- `DELETE` ~35–40% rozłożone losowo.
- Odczytujemy:
  - `sys.dm_db_index_physical_stats` → `ghost_record_count`
  - `sys.dm_db_index_operational_stats` → `leaf_ghost_count`

### 4) Patrzymy na stronę w DBCC PAGE
- `DBCC PAGE (GhostLabDB, file_id, page_id, 3)`
- Szukamy slotów oznaczonych jako **Ghost** (Status Bits).

### 5) Sprzątamy ghosty i porównujemy
- Opcja A: `ALTER INDEX … REORGANIZE` (lekko)
- Opcja B: `ALTER INDEX … REBUILD` (mocno)
- Porównujemy liczniki ghostów przed/po.

> **Uwaga o TF 661:** Możesz **tymczasowo** wyłączyć background Ghost Cleanup (`DBCC TRACEON(661, -1)`), aby ghosty „poczekały” do kroku 5. **Zawsze** wyłącz po labie (`DBCC TRACEOFF(661, -1)`).

---

## Weryfikacja i metryki
- `ghost_record_count` w `sys.dm_db_index_physical_stats`.
- `leaf_ghost_count` w `sys.dm_db_index_operational_stats`.
- `DBCC PAGE` — czy slot ma flagę GHOST?
- Różnica w liczbie stron i free space po REBUILD/REORGANIZE.

## Sprzątanie
- `DROP DATABASE GhostLabDB;`
- Jeśli włączałeś TF 661 globalnie → `DBCC TRACEOFF(661, -1)`.

## FAQ
- **Czemu nie widzę ghostów w PAGE?** Być może background Ghost Cleanup już je skasował. Wykonaj `DELETE`, a zaraz potem `DBCC IND` → `DBCC PAGE` zanim upłynie parę sekund **lub** włącz TF 661 na czas labu (ostrożnie).
- **Czy `DBCC CLEANTABLE` usuwa ghosty?** Nie — dotyczy odzyskiwania miejsca po kolumnach zmiennych długości i `DROP COLUMN`, nie ghost records.
- **Czy REORGANIZE zawsze czyści ghosty?** Reorganize sprząta i upakowuje strony liści, w praktyce zobaczysz spadek ghostów. REBUILD — na pewno.

---

## Referencje do DMVs (przydatne)
- `sys.dm_db_index_physical_stats` (ghost_record_count)
- `sys.dm_db_index_operational_stats` (leaf_ghost_count, range_scan_count, itd.)
- `sys.dm_tran_database_transactions` (dla ciekawskich recovery)
- `sys.fn_PhysLocCracker` (rozbicie `%%physloc%%`)

Powodzenia — to jest esencja „internals w praktyce”. 
