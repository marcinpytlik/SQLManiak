/*
===============================================================================
 Title:      list_dmvs.sql
 Author:     Marcin (SQLManiak)
 License:    Creative Commons BY 4.0
 Repository: https://github.com/marcinpytlik/sqlmaniak

 Purpose:
   Generates a categorized list of all Dynamic Management Views (DMVs)
   available in the current SQL Server instance. Each DMV is mapped to
   a functional category and enriched with a direct link to official
   Microsoft Docs documentation.

 Tested on:
   - SQL Server 2016 (SP3)
   - SQL Server 2019
   - SQL Server 2022 (Developer Edition)

 Usage:
   Run in SSMS, Azure Data Studio or sqlcmd. Results include:
     * DMV name
     * Category
     * Short description
     * Docs link

 Notes:
   - Only DMVs (views, type = 'V') are included, DMFs (functions) are excluded.
   - Docs links are constructed dynamically and point to
     https://learn.microsoft.com/sql/...

===============================================================================
*/

WITH dmvs AS (
    SELECT name
    FROM sys.all_objects
    WHERE is_ms_shipped = 1
      AND type = 'V'
      AND name LIKE 'dm[_]%'  -- only DMV (views)
)
SELECT
  Category =
    CASE
      WHEN name LIKE 'dm[_]os[_]%'     THEN 'OS / SQLOS'
      WHEN name LIKE 'dm[_]exec[_]%'   THEN 'Execution / Requests / Cache'
      WHEN name LIKE 'dm[_]db[_]%'     THEN 'Database / Indexes / Space'
      WHEN name LIKE 'dm[_]io[_]%'     THEN 'I/O'
      WHEN name LIKE 'dm[_]tran[_]%'   THEN 'Transactions / Locks / Versioning'
      WHEN name LIKE 'dm[_]xe[_]%'     THEN 'Extended Events'
      WHEN name LIKE 'dm[_]hadr[_]%'   THEN 'Always On / HADR'
      WHEN name LIKE 'dm[_]resource[_]governor[_]%' THEN 'Resource Governor'
      WHEN name LIKE 'dm[_]broker[_]%' THEN 'Service Broker'
      WHEN name LIKE 'dm[_]clr[_]%'    THEN 'CLR'
      WHEN name LIKE 'dm[_]fts[_]%'    THEN 'Full-Text Search'
      WHEN name LIKE 'dm[_]server[_]%' THEN 'Server (audit/usługi/inne)'
      WHEN name LIKE 'dm[_]cdc[_]%'    THEN 'Change Data Capture (CDC)'
      WHEN name LIKE 'dm[_]repl[_]%'   THEN 'Replication'
      ELSE 'Inne'
    END,
  DMV = 'sys.' + name,
  Opis = CASE
      WHEN name LIKE 'dm[_]os[_]%'   THEN 'Stan SQLOS/OS: pamięć, schedulery, wątki, oczekiwania, bufor stron itd.'
      WHEN name LIKE 'dm[_]exec[_]%' THEN 'Sesje/połączenia/żądania, granty pamięci, statystyki planów i optymalizatora.'
      WHEN name LIKE 'dm[_]db[_]%'   THEN 'Stan bazy: indeksy, partycje, użycie przestrzeni, brakujące indeksy, cechy SKU.'
      WHEN name LIKE 'dm[_]io[_]%'   THEN 'We/Wy na poziomie instancji i plików (oczekujące I/O, kolejki).'
      WHEN name LIKE 'dm[_]tran[_]%' THEN 'Transakcje i blokady, wersjonowanie, zaległe wersje.'
      WHEN name LIKE 'dm[_]xe[_]%'   THEN 'Extended Events: sesje, cele, obiekty, mapowania.'
      WHEN name LIKE 'dm[_]hadr[_]%' THEN 'Always On AG: stany grup, replik, baz, auto-page-repair, klaster.'
      WHEN name LIKE 'dm[_]resource[_]governor[_]%' THEN 'Pule/Workload groups i ich statystyki, affinity.'
      WHEN name LIKE 'dm[_]broker[_]%' THEN 'Service Broker: kolejki, transmisja, połączenia, zadania.'
      WHEN name LIKE 'dm[_]clr[_]%'  THEN 'CLR: domeny aplikacji, załadowane assembly, zadania CLR.'
      WHEN name LIKE 'dm[_]fts[_]%'  THEN 'Full-Text: populacje, bufory, słowa kluczowe.'
      WHEN name LIKE 'dm[_]server[_]%' THEN 'Usługi instancji, audyt, zrzuty pamięci itp.'
      WHEN name LIKE 'dm[_]cdc[_]%'  THEN 'CDC: sesje skanów logu, błędy.'
      WHEN name LIKE 'dm[_]repl[_]%' THEN 'Replikacja: informacje o transakcjach replikacji.'
      ELSE 'Różne DMV dla specyficznych obszarów.'
    END,
  Docs = 'https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/'
         + REPLACE(LOWER('sys-' + name), '_','-')
         + '-transact-sql'
FROM dmvs
ORDER BY Category, DMV;
