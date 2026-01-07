/* 05_Table_Health_Indexes_Stats.sql
   Szybki przegląd „czy ta tabela ma gdzie cierpieć”.
   - indeksy + statystyki + data ostatniej aktualizacji
   - operacyjne liczniki (page splits, latch waits)
   - fragmentacja + zagęszczenie stron

   Ustaw @Schema/@Table.
*/
DECLARE @Schema sysname = N'dbo';
DECLARE @Table  sysname = N'Nazwatabeli';

DECLARE @ObjectId int = OBJECT_ID(QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table));
IF @ObjectId IS NULL
BEGIN
    RAISERROR('Nie znaleziono tabeli %s.%s', 16, 1, @Schema, @Table);
    RETURN;
END;

-- 1) Indeksy
SELECT
    i.index_id,
    i.name AS index_name,
    i.type_desc,
    i.is_primary_key,
    i.is_unique,
    i.fill_factor,
    i.has_filter,
    i.filter_definition
FROM sys.indexes i
WHERE i.object_id = @ObjectId
ORDER BY i.index_id;

-- Klucze i INCLUDE
SELECT
    i.name AS index_name,
    ic.key_ordinal,
    ic.is_included_column,
    c.name AS column_name
FROM sys.indexes i
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.object_id = @ObjectId
ORDER BY i.index_id, ic.is_included_column, ic.key_ordinal, c.name;

-- 2) Statystyki + STATS_DATE
SELECT
    s.name AS stats_name,
    STATS_DATE(s.object_id, s.stats_id) AS stats_last_updated,
    sp.rows,
    sp.rows_sampled,
    sp.modification_counter
FROM sys.stats s
OUTER APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE s.object_id = @ObjectId
ORDER BY stats_last_updated DESC;

-- 3) Operacyjne: page splits / latch waits (od startu instancji)
SELECT
    i.name AS index_name,
    ios.leaf_insert_count,
    ios.leaf_update_count,
    ios.leaf_delete_count,
    ios.leaf_split_count,
    ios.nonleaf_insert_count,
    ios.nonleaf_update_count,
    ios.nonleaf_delete_count,
    ios.page_latch_wait_count,
    ios.page_latch_wait_in_ms,
    ios.page_io_latch_wait_count,
    ios.page_io_latch_wait_in_ms
FROM sys.indexes i
OUTER APPLY sys.dm_db_index_operational_stats(DB_ID(), @ObjectId, i.index_id, NULL) ios
WHERE i.object_id = @ObjectId
ORDER BY ios.leaf_split_count DESC;

-- 4) Fragmentacja + zagęszczenie (uważaj na duże tabele; tryb SAMPLED)
SELECT
    ips.index_id,
    i.name AS index_name,
    ips.avg_fragmentation_in_percent,
    ips.avg_page_space_used_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), @ObjectId, NULL, NULL, 'SAMPLED') ips
JOIN sys.indexes i ON i.object_id = ips.object_id AND i.index_id = ips.index_id
ORDER BY ips.page_count DESC;

-- 5) Czy są triggery / FK? (częsty winowajca przy INSERT/MERGE)
SELECT name, is_instead_of_trigger, is_disabled, create_date, modify_date
FROM sys.triggers
WHERE parent_id = @ObjectId;

SELECT
    fk.name AS fk_name,
    OBJECT_NAME(fk.parent_object_id) AS parent_table,
    OBJECT_NAME(fk.referenced_object_id) AS referenced_table,
    fk.is_disabled, fk.is_not_trusted,
    fk.delete_referential_action_desc,
    fk.update_referential_action_desc
FROM sys.foreign_keys fk
WHERE fk.parent_object_id = @ObjectId OR fk.referenced_object_id = @ObjectId
ORDER BY fk.name;
