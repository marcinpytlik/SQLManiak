marcin, da się to sprawdzić całkiem sensownie, ale trzeba rozdzielić temat na 4 koszyki, bo „czy indeksy są ok” to w SQL Server worek bez dna:

czy brakuje indeksów

czy są duplikaty / nakładanie się

czy są nieużywane

czy są kosztowne w utrzymaniu

Poniżej masz gotowy pakiet diagnostyczny pod SQL Server 2016.

1) Brakujące indeksy (Missing Index DMVs)

To jest pierwszy trop, ale z gwiazdką: DMV podpowiadają, nie wyrocznia z góry Synaj.

SELECT TOP (50)
    DB_NAME(mid.database_id) AS database_name,
    OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id) AS schema_name,
    OBJECT_NAME(mid.object_id, mid.database_id) AS table_name,
    migs.user_seeks,
    migs.user_scans,
    migs.avg_total_user_cost,
    migs.avg_user_impact,
    CAST(
        migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans)
        AS DECIMAL(18,2)
    ) AS improvement_measure,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id, mid.database_id) + '_Auto'
        + ' ON '
        + OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id) + '.'
        + OBJECT_NAME(mid.object_id, mid.database_id)
        + ' ('
        + ISNULL(mid.equality_columns, '')
        + CASE
            WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ', '
            ELSE ''
          END
        + ISNULL(mid.inequality_columns, '')
        + ')'
        + CASE
            WHEN mid.included_columns IS NOT NULL THEN ' INCLUDE (' + mid.included_columns + ')'
            ELSE ''
          END AS suggested_create_index
FROM sys.dm_db_missing_index_group_stats AS migs
JOIN sys.dm_db_missing_index_groups AS mig
    ON migs.group_handle = mig.index_group_handle
JOIN sys.dm_db_missing_index_details AS mid
    ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY improvement_measure DESC;
Uwaga

Te DMV:

resetują się po restarcie SQL Server,

nie wiedzą, że jakiś podobny indeks już istnieje,

często proponują indeksy zbliżone do już istniejących.

Czyli: traktuj to jako listę kandydatów, nie polecenia do bezmyślnego wykonania.

2) Indeksy zduplikowane lub bardzo podobne

To jest złoto, bo w wielu bazach ludzie mają po 5 indeksów robiących prawie to samo.

2a) Indeksy z identycznym kluczem
;WITH idx AS
(
    SELECT
        i.object_id,
        i.index_id,
        s.name AS schema_name,
        t.name AS table_name,
        i.name AS index_name,
        STUFF(
        (
            SELECT ',' + c.name
            FROM sys.index_columns ic
            JOIN sys.columns c
                ON c.object_id = ic.object_id
               AND c.column_id = ic.column_id
            WHERE ic.object_id = i.object_id
              AND ic.index_id = i.index_id
              AND ic.is_included_column = 0
            ORDER BY ic.key_ordinal
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 1, '') AS key_columns
    FROM sys.indexes i
    JOIN sys.tables t
        ON t.object_id = i.object_id
    JOIN sys.schemas s
        ON s.schema_id = t.schema_id
    WHERE i.type IN (1,2)
      AND i.is_hypothetical = 0
      AND i.name IS NOT NULL
)
SELECT
    a.schema_name,
    a.table_name,
    a.index_name AS index_1,
    b.index_name AS index_2,
    a.key_columns
FROM idx a
JOIN idx b
    ON a.object_id = b.object_id
   AND a.index_id < b.index_id
   AND a.key_columns = b.key_columns
ORDER BY a.schema_name, a.table_name, a.key_columns;

To pokaże indeksy, które mają ten sam klucz.
Jeszcze nie znaczy, że jeden jest zbędny — bo mogą różnić się INCLUDE, filtrem, unikalnością — ale to bardzo dobry trop.

2b) Indeksy, gdzie jeden jest prefiksem drugiego (nakładanie)

Przykład:

IX_A (Col1)

IX_B (Col1, Col2)

W wielu przypadkach IX_A może być zbędny, ale nie zawsze.

;WITH idx AS
(
    SELECT
        i.object_id,
        i.index_id,
        s.name AS schema_name,
        t.name AS table_name,
        i.name AS index_name,
        STUFF(
        (
            SELECT ',' + c.name
            FROM sys.index_columns ic
            JOIN sys.columns c
                ON c.object_id = ic.object_id
               AND c.column_id = ic.column_id
            WHERE ic.object_id = i.object_id
              AND ic.index_id = i.index_id
              AND ic.is_included_column = 0
            ORDER BY ic.key_ordinal
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 1, '') AS key_columns
    FROM sys.indexes i
    JOIN sys.tables t
        ON t.object_id = i.object_id
    JOIN sys.schemas s
        ON s.schema_id = t.schema_id
    WHERE i.type IN (1,2)
      AND i.is_hypothetical = 0
      AND i.name IS NOT NULL
)
SELECT
    a.schema_name,
    a.table_name,
    a.index_name AS narrower_index,
    a.key_columns AS narrower_keys,
    b.index_name AS wider_index,
    b.key_columns AS wider_keys
FROM idx a
JOIN idx b
    ON a.object_id = b.object_id
   AND a.index_id <> b.index_id
   AND b.key_columns LIKE a.key_columns + ',%'
ORDER BY a.schema_name, a.table_name, a.index_name;

To są kandydaci do przeglądu:

węższy indeks może być zbędny,

ale czasem jest lżejszy i bardzo użyteczny do seeków / sortów / mniejszego I/O.

Nie kasuj bez sprawdzenia użycia.

3) Nie używane indeksy

To klasyk. Jeśli indeks nie jest używany, a ma aktualizacje, to jest balast.

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    i.name AS index_name,
    i.index_id,
    ISNULL(us.user_seeks, 0) AS user_seeks,
    ISNULL(us.user_scans, 0) AS user_scans,
    ISNULL(us.user_lookups, 0) AS user_lookups,
    ISNULL(us.user_updates, 0) AS user_updates
FROM sys.indexes i
JOIN sys.tables t
    ON t.object_id = i.object_id
JOIN sys.schemas s
    ON s.schema_id = t.schema_id
LEFT JOIN sys.dm_db_index_usage_stats us
    ON us.object_id = i.object_id
   AND us.index_id = i.index_id
   AND us.database_id = DB_ID()
WHERE i.type IN (1,2)
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND i.is_hypothetical = 0
ORDER BY
    ISNULL(us.user_seeks, 0)
  + ISNULL(us.user_scans, 0)
  + ISNULL(us.user_lookups, 0) ASC,
    ISNULL(us.user_updates, 0) DESC;
Na co patrzeć

Podejrzane są indeksy, które mają:

user_seeks = 0

user_scans = 0

user_lookups = 0

a jednocześnie duże user_updates

Czyli:

nikt z nich nie czyta,

ale każdy INSERT/UPDATE/DELETE musi je utrzymywać.

To jest klasyczny kandydat do wywalenia — o ile DMV obejmuje reprezentatywny okres pracy, bo po restarcie liczniki są puste.

4) Rozmiar i koszt indeksów

Żeby zobaczyć, które indeksy są duże i potencjalnie drogie:

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    i.name AS index_name,
    i.index_id,
    SUM(ps.page_count) AS page_count,
    CAST(SUM(ps.page_count) * 8.0 / 1024 AS DECIMAL(18,2)) AS size_mb
FROM sys.indexes i
JOIN sys.tables t
    ON t.object_id = i.object_id
JOIN sys.schemas s
    ON s.schema_id = t.schema_id
JOIN sys.dm_db_partition_stats ps
    ON ps.object_id = i.object_id
   AND ps.index_id = i.index_id
WHERE i.index_id > 0
GROUP BY
    s.name, t.name, i.name, i.index_id
ORDER BY size_mb DESC;

Duży + nieużywany = bardzo ciekawy kandydat do sprzątania.

5) Fragmentacja (to nie zawsze najważniejsze, ale warto sprawdzić)
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    i.name AS index_name,
    ips.index_type_desc,
    ips.avg_fragmentation_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i
    ON i.object_id = ips.object_id
   AND i.index_id = ips.index_id
JOIN sys.tables t
    ON t.object_id = ips.object_id
JOIN sys.schemas s
    ON s.schema_id = t.schema_id
WHERE ips.index_id > 0
  AND ips.page_count > 1000
ORDER BY ips.avg_fragmentation_in_percent DESC;

Ale ważne:
fragmentacja nie jest pierwszą rzeczą do naprawy, jeśli masz:

brakujące indeksy,

duplikaty,

złe plany,

lookup storm.

Nie daj się wciągnąć w kult „rebuild everything”.

6) Jak sprawdzić, czy indeks pokrywa zapytanie

Tu wchodzimy w praktykę. Najlepsza metoda:

odpal konkretne zapytanie,

włącz Actual Execution Plan,

sprawdź:

Index Seek / Index Scan

Key Lookup / RID Lookup

Missing Index hint

operator Sort (bo może brakować właściwej kolejności kluczy)

Gdy widzisz:

Index Seek + Key Lookup wykonywany tysiące razy,
to często znaczy:

indeks jest prawie dobry,

ale nie pokrywa zapytania,

brakuje kolumn w INCLUDE.

To jest często lepszy ruch niż tworzenie nowego indeksu „od zera”.

7) Szybki raport „co wygląda podejrzanie”

To jest praktyczny filtr na kandydatów do przeglądu:

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    i.name AS index_name,
    ISNULL(us.user_seeks, 0) AS seeks,
    ISNULL(us.user_scans, 0) AS scans,
    ISNULL(us.user_lookups, 0) AS lookups,
    ISNULL(us.user_updates, 0) AS updates,
    CAST(SUM(ps.page_count) * 8.0 / 1024 AS DECIMAL(18,2)) AS size_mb
FROM sys.indexes i
JOIN sys.tables t
    ON t.object_id = i.object_id
JOIN sys.schemas s
    ON s.schema_id = t.schema_id
LEFT JOIN sys.dm_db_index_usage_stats us
    ON us.object_id = i.object_id
   AND us.index_id = i.index_id
   AND us.database_id = DB_ID()
JOIN sys.dm_db_partition_stats ps
    ON ps.object_id = i.object_id
   AND ps.index_id = i.index_id
WHERE i.type IN (1,2)
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
GROUP BY
    s.name, t.name, i.name,
    us.user_seeks, us.user_scans, us.user_lookups, us.user_updates
HAVING
    ISNULL(us.user_seeks, 0)
  + ISNULL(us.user_scans, 0)
  + ISNULL(us.user_lookups, 0) = 0
ORDER BY size_mb DESC, updates DESC;

To daje listę:

nieczytanych,

ale utrzymywanych,

i często sporych indeksów.

8) Czego nie robić

Nie rób od razu:

kasowania indeksów tylko dlatego, że „0 seeks”

tworzenia wszystkich missing indexów z DMV

usuwania „węższego” indeksu tylko dlatego, że istnieje „szerszy”

Bo trzeba uwzględnić:

okno obserwacji

joby nocne

raporty miesięczne

plany zapytań

kolejność kolumn

filtry (filtered indexes)

unikalność

SQL Server lubi wyglądać oczywiście, dopóki nie zrobi ci psikusa w ostatni dzień miesiąca.

9) Najpraktyczniejszy plan działania

Ja bym zrobił tak:

zbierz missing indexes

zbierz duplicate/overlapping

zbierz unused indexes

weź 5 najcięższych zapytań i sprawdź plan wykonania

dopiero wtedy:

scalaj indeksy,

dodawaj INCLUDE,

usuwaj śmieci

10) Chcesz to mieć w jednym strzale?

Mogę ci przygotować gotową procedurę, np. dbo.usp_IndexAudit2016, która:

pokazuje brakujące indeksy,

wykrywa duplikaty,

wykrywa nakładanie,

pokazuje nieużywane,

pokazuje największe indeksy,

i daje kolumnę Recommendation typu:

REVIEW_MISSING

REVIEW_DUPLICATE

REVIEW_UNUSED

REVIEW_OVERLAP

To już byłby porządny warsztat DBA, a nie ręczne kopanie po DMV jak archeolog po deszczu.

poprosze o ten skrypt
Myślał przez 18s

marcin, jasne — poniżej masz gotowy skrypt dbo.usp_IndexAudit2016 pod SQL Server 2016.

Procedura zwraca kilka zestawów wyników:

Missing indexes

Duplicate indexes (ten sam klucz)

Overlapping indexes (jeden jest prefiksem drugiego)

Unused indexes

Largest indexes

Fragmentation

Summary / Recommendations

To jest audyt DBA, nie wyrok sądu — traktuj jako listę kandydatów do analizy, nie automat do kasowania wszystkiego, co wygląda podejrzanie.

Skrypt: dbo.usp_IndexAudit2016
USE [TwojaBaza];
GO

IF OBJECT_ID(N'dbo.usp_IndexAudit2016', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_IndexAudit2016;
GO

CREATE PROCEDURE dbo.usp_IndexAudit2016
(
      @TopMissing           INT = 50
    , @MinPageCountFrag     INT = 1000
    , @IncludeFrag          BIT = 1
    , @OnlyUserTables       BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       INFO
       ========================================================= */
    DECLARE @DbId INT = DB_ID();

    SELECT
          DB_NAME() AS database_name
        , @@SERVERNAME AS server_name
        , GETDATE() AS audit_time
        , sqlserver_start_time
    FROM sys.dm_os_sys_info;

    /* =========================================================
       BAZA ROBOCZA: METADATA INDEKSÓW
       ========================================================= */
    IF OBJECT_ID('tempdb..#IndexBase') IS NOT NULL
        DROP TABLE #IndexBase;

    CREATE TABLE #IndexBase
    (
          object_id              INT             NOT NULL
        , index_id               INT             NOT NULL
        , schema_name            SYSNAME         NOT NULL
        , table_name             SYSNAME         NOT NULL
        , index_name             SYSNAME         NULL
        , index_type_desc        NVARCHAR(60)    NOT NULL
        , is_unique              BIT             NOT NULL
        , is_primary_key         BIT             NOT NULL
        , is_unique_constraint   BIT             NOT NULL
        , has_filter             BIT             NOT NULL
        , filter_definition      NVARCHAR(MAX)   NULL
        , key_columns            NVARCHAR(MAX)   NULL
        , include_columns        NVARCHAR(MAX)   NULL
        , key_count              INT             NULL
    );

    ;WITH idx AS
    (
        SELECT
              i.object_id
            , i.index_id
            , s.name AS schema_name
            , t.name AS table_name
            , i.name AS index_name
            , i.type_desc AS index_type_desc
            , i.is_unique
            , i.is_primary_key
            , i.is_unique_constraint
            , i.has_filter
            , i.filter_definition
        FROM sys.indexes i
        JOIN sys.tables t
            ON t.object_id = i.object_id
        JOIN sys.schemas s
            ON s.schema_id = t.schema_id
        WHERE i.type IN (1,2)                -- clustered / nonclustered
          AND i.is_hypothetical = 0
          AND (@OnlyUserTables = 0 OR t.is_ms_shipped = 0)
    )
    INSERT INTO #IndexBase
    (
          object_id
        , index_id
        , schema_name
        , table_name
        , index_name
        , index_type_desc
        , is_unique
        , is_primary_key
        , is_unique_constraint
        , has_filter
        , filter_definition
        , key_columns
        , include_columns
        , key_count
    )
    SELECT
          idx.object_id
        , idx.index_id
        , idx.schema_name
        , idx.table_name
        , idx.index_name
        , idx.index_type_desc
        , idx.is_unique
        , idx.is_primary_key
        , idx.is_unique_constraint
        , idx.has_filter
        , idx.filter_definition
        , kc.key_columns
        , ic.include_columns
        , kc.key_count
    FROM idx
    OUTER APPLY
    (
        SELECT
              STUFF
              (
                  (
                      SELECT
                          N',' + QUOTENAME(c.name)
                          + CASE WHEN ic2.is_descending_key = 1 THEN N' DESC' ELSE N' ASC' END
                      FROM sys.index_columns ic2
                      JOIN sys.columns c
                          ON c.object_id = ic2.object_id
                         AND c.column_id = ic2.column_id
                      WHERE ic2.object_id = idx.object_id
                        AND ic2.index_id = idx.index_id
                        AND ic2.is_included_column = 0
                      ORDER BY ic2.key_ordinal
                      FOR XML PATH(''), TYPE
                  ).value('.', 'nvarchar(max)')
                , 1, 1, N''
              ) AS key_columns
            , COUNT(*) AS key_count
        FROM sys.index_columns ic2
        WHERE ic2.object_id = idx.object_id
          AND ic2.index_id = idx.index_id
          AND ic2.is_included_column = 0
    ) kc
    OUTER APPLY
    (
        SELECT
            STUFF
            (
                (
                    SELECT
                        N',' + QUOTENAME(c.name)
                    FROM sys.index_columns ic3
                    JOIN sys.columns c
                        ON c.object_id = ic3.object_id
                       AND c.column_id = ic3.column_id
                    WHERE ic3.object_id = idx.object_id
                      AND ic3.index_id = idx.index_id
                      AND ic3.is_included_column = 1
                    ORDER BY c.column_id
                    FOR XML PATH(''), TYPE
                ).value('.', 'nvarchar(max)')
              , 1, 1, N''
            ) AS include_columns
    ) ic;

    /* =========================================================
       USAGE + SIZE
       ========================================================= */
    IF OBJECT_ID('tempdb..#IndexStats') IS NOT NULL
        DROP TABLE #IndexStats;

    CREATE TABLE #IndexStats
    (
          object_id         INT           NOT NULL
        , index_id          INT           NOT NULL
        , user_seeks        BIGINT        NOT NULL
        , user_scans        BIGINT        NOT NULL
        , user_lookups      BIGINT        NOT NULL
        , user_updates      BIGINT        NOT NULL
        , last_user_seek    DATETIME      NULL
        , last_user_scan    DATETIME      NULL
        , last_user_lookup  DATETIME      NULL
        , last_user_update  DATETIME      NULL
        , page_count        BIGINT        NOT NULL
        , size_mb           DECIMAL(18,2) NOT NULL
        , row_count         BIGINT        NOT NULL
    );

    INSERT INTO #IndexStats
    (
          object_id
        , index_id
        , user_seeks
        , user_scans
        , user_lookups
        , user_updates
        , last_user_seek
        , last_user_scan
        , last_user_lookup
        , last_user_update
        , page_count
        , size_mb
        , row_count
    )
    SELECT
          i.object_id
        , i.index_id
        , ISNULL(us.user_seeks, 0)
        , ISNULL(us.user_scans, 0)
        , ISNULL(us.user_lookups, 0)
        , ISNULL(us.user_updates, 0)
        , us.last_user_seek
        , us.last_user_scan
        , us.last_user_lookup
        , us.last_user_update
        , ISNULL(SUM(ps.page_count), 0) AS page_count
        , CAST(ISNULL(SUM(ps.page_count), 0) * 8.0 / 1024.0 AS DECIMAL(18,2)) AS size_mb
        , ISNULL(SUM(ps.row_count), 0) AS row_count
    FROM #IndexBase i
    LEFT JOIN sys.dm_db_index_usage_stats us
        ON us.database_id = @DbId
       AND us.object_id = i.object_id
       AND us.index_id = i.index_id
    LEFT JOIN sys.dm_db_partition_stats ps
        ON ps.object_id = i.object_id
       AND ps.index_id = i.index_id
    GROUP BY
          i.object_id
        , i.index_id
        , us.user_seeks
        , us.user_scans
        , us.user_lookups
        , us.user_updates
        , us.last_user_seek
        , us.last_user_scan
        , us.last_user_lookup
        , us.last_user_update;

    /* =========================================================
       1) MISSING INDEXES
       ========================================================= */
    ;WITH mi AS
    (
        SELECT TOP (@TopMissing)
              DB_NAME(mid.database_id) AS database_name
            , OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id) AS schema_name
            , OBJECT_NAME(mid.object_id, mid.database_id) AS table_name
            , migs.user_seeks
            , migs.user_scans
            , migs.avg_total_user_cost
            , migs.avg_user_impact
            , CAST
              (
                    migs.avg_total_user_cost
                  * migs.avg_user_impact
                  * (migs.user_seeks + migs.user_scans)
                AS DECIMAL(18,2)
              ) AS improvement_measure
            , mid.equality_columns
            , mid.inequality_columns
            , mid.included_columns
            , N'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id, mid.database_id) + N'_Auto'
              + N' ON '
              + QUOTENAME(OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id))
              + N'.'
              + QUOTENAME(OBJECT_NAME(mid.object_id, mid.database_id))
              + N' ('
              + ISNULL(mid.equality_columns, N'')
              + CASE
                    WHEN mid.equality_columns IS NOT NULL
                     AND mid.inequality_columns IS NOT NULL THEN N', '
                    ELSE N''
                END
              + ISNULL(mid.inequality_columns, N'')
              + N')'
              + CASE
                    WHEN mid.included_columns IS NOT NULL
                    THEN N' INCLUDE (' + mid.included_columns + N')'
                    ELSE N''
                END AS suggested_create_index
            , N'REVIEW_MISSING' AS recommendation
        FROM sys.dm_db_missing_index_group_stats AS migs
        JOIN sys.dm_db_missing_index_groups AS mig
            ON migs.group_handle = mig.index_group_handle
        JOIN sys.dm_db_missing_index_details AS mid
            ON mig.index_handle = mid.index_handle
        WHERE mid.database_id = @DbId
        ORDER BY improvement_measure DESC
    )
    SELECT *
    FROM mi
    ORDER BY improvement_measure DESC;

    /* =========================================================
       2) DUPLICATE INDEXES (IDENTYCZNY KLUCZ)
       ========================================================= */
    ;WITH d AS
    (
        SELECT
              a.schema_name
            , a.table_name
            , a.index_name AS index_1
            , b.index_name AS index_2
            , a.index_type_desc
            , a.key_columns
            , a.include_columns AS include_1
            , b.include_columns AS include_2
            , a.has_filter AS has_filter_1
            , b.has_filter AS has_filter_2
            , a.filter_definition AS filter_1
            , b.filter_definition AS filter_2
            , N'REVIEW_DUPLICATE' AS recommendation
        FROM #IndexBase a
        JOIN #IndexBase b
            ON a.object_id = b.object_id
           AND a.index_id < b.index_id
           AND ISNULL(a.key_columns, N'') = ISNULL(b.key_columns, N'')
    )
    SELECT *
    FROM d
    ORDER BY schema_name, table_name, key_columns;

    /* =========================================================
       3) OVERLAPPING INDEXES (JEDEN PREFIKSEM DRUGIEGO)
       Uwaga: heurystyka tekstowa, dobry kandydat do review
       ========================================================= */
    ;WITH o AS
    (
        SELECT
              a.schema_name
            , a.table_name
            , a.index_name AS narrower_index
            , a.key_columns AS narrower_keys
            , a.include_columns AS narrower_includes
            , b.index_name AS wider_index
            , b.key_columns AS wider_keys
            , b.include_columns AS wider_includes
            , N'REVIEW_OVERLAP' AS recommendation
        FROM #IndexBase a
        JOIN #IndexBase b
            ON a.object_id = b.object_id
           AND a.index_id <> b.index_id
           AND a.key_count < b.key_count
           AND LEFT(ISNULL(b.key_columns, N''), LEN(ISNULL(a.key_columns, N''))) = ISNULL(a.key_columns, N'')
           AND SUBSTRING(ISNULL(b.key_columns, N''), LEN(ISNULL(a.key_columns, N'')) + 1, 1) = N','
    )
    SELECT DISTINCT *
    FROM o
    ORDER BY schema_name, table_name, narrower_index, wider_index;

    /* =========================================================
       4) UNUSED INDEXES
       ========================================================= */
    ;WITH u AS
    (
        SELECT
              b.schema_name
            , b.table_name
            , b.index_name
            , b.index_type_desc
            , b.key_columns
            , b.include_columns
            , s.user_seeks
            , s.user_scans
            , s.user_lookups
            , s.user_updates
            , s.last_user_seek
            , s.last_user_scan
            , s.last_user_lookup
            , s.last_user_update
            , s.page_count
            , s.size_mb
            , s.row_count
            , CASE
                WHEN (s.user_seeks + s.user_scans + s.user_lookups) = 0
                 AND s.user_updates > 0
                    THEN N'REVIEW_UNUSED'
                WHEN (s.user_seeks + s.user_scans + s.user_lookups) = 0
                 AND s.user_updates = 0
                    THEN N'REVIEW_NEVER_USED_OR_RESET'
                ELSE N'INFO'
              END AS recommendation
        FROM #IndexBase b
        JOIN #IndexStats s
            ON s.object_id = b.object_id
           AND s.index_id = b.index_id
        WHERE b.is_primary_key = 0
          AND b.is_unique_constraint = 0
    )
    SELECT *
    FROM u
    WHERE recommendation IN (N'REVIEW_UNUSED', N'REVIEW_NEVER_USED_OR_RESET')
    ORDER BY size_mb DESC, user_updates DESC, schema_name, table_name, index_name;

    /* =========================================================
       5) LARGEST INDEXES
       ========================================================= */
    SELECT
          b.schema_name
        , b.table_name
        , b.index_name
        , b.index_type_desc
        , b.key_columns
        , b.include_columns
        , s.page_count
        , s.size_mb
        , s.row_count
        , s.user_seeks
        , s.user_scans
        , s.user_lookups
        , s.user_updates
        , CASE
            WHEN (s.user_seeks + s.user_scans + s.user_lookups) = 0
             AND b.is_primary_key = 0
             AND b.is_unique_constraint = 0
                THEN N'REVIEW_LARGE_AND_UNUSED'
            ELSE N'INFO'
          END AS recommendation
    FROM #IndexBase b
    JOIN #IndexStats s
        ON s.object_id = b.object_id
       AND s.index_id = b.index_id
    ORDER BY s.size_mb DESC, b.schema_name, b.table_name, b.index_name;

    /* =========================================================
       6) FRAGMENTATION
       ========================================================= */
    IF @IncludeFrag = 1
    BEGIN
        SELECT
              s.name AS schema_name
            , t.name AS table_name
            , i.name AS index_name
            , ips.index_type_desc
            , ips.avg_fragmentation_in_percent
            , ips.page_count
            , CASE
                WHEN ips.page_count < @MinPageCountFrag THEN N'IGNORE_SMALL'
                WHEN ips.avg_fragmentation_in_percent >= 30 THEN N'REVIEW_REBUILD'
                WHEN ips.avg_fragmentation_in_percent >= 5 THEN N'REVIEW_REORGANIZE'
                ELSE N'OK'
              END AS recommendation
        FROM sys.dm_db_index_physical_stats(@DbId, NULL, NULL, NULL, 'LIMITED') ips
        JOIN sys.indexes i
            ON i.object_id = ips.object_id
           AND i.index_id = ips.index_id
        JOIN sys.tables t
            ON t.object_id = ips.object_id
        JOIN sys.schemas s
            ON s.schema_id = t.schema_id
        WHERE ips.index_id > 0
          AND ips.page_count >= @MinPageCountFrag
          AND (@OnlyUserTables = 0 OR t.is_ms_shipped = 0)
        ORDER BY ips.avg_fragmentation_in_percent DESC, ips.page_count DESC;
    END

    /* =========================================================
       7) SUMMARY / RECOMMENDATIONS
       ========================================================= */
    ;WITH x AS
    (
        SELECT
              b.schema_name
            , b.table_name
            , b.index_name
            , b.key_columns
            , b.include_columns
            , s.size_mb
            , s.user_seeks
            , s.user_scans
            , s.user_lookups
            , s.user_updates
            , CASE
                WHEN b.is_primary_key = 1 OR b.is_unique_constraint = 1
                    THEN N'KEEP_CONSTRAINT'
                WHEN (s.user_seeks + s.user_scans + s.user_lookups) = 0
                 AND s.user_updates > 0
                 AND s.size_mb >= 10
                    THEN N'REVIEW_REMOVE_OR_DISABLE'
                WHEN (s.user_seeks + s.user_scans + s.user_lookups) = 0
                 AND s.user_updates = 0
                    THEN N'REVIEW_AFTER_LONGER_OBSERVATION'
                WHEN s.user_updates > ((s.user_seeks + s.user_scans + s.user_lookups) * 20)
                 AND s.size_mb >= 50
                    THEN N'REVIEW_WRITE_HEAVY'
                ELSE N'INFO'
              END AS recommendation
        FROM #IndexBase b
        JOIN #IndexStats s
            ON s.object_id = b.object_id
           AND s.index_id = b.index_id
    )
    SELECT *
    FROM x
    WHERE recommendation <> N'INFO'
    ORDER BY
          CASE recommendation
              WHEN N'REVIEW_REMOVE_OR_DISABLE' THEN 1
              WHEN N'REVIEW_WRITE_HEAVY' THEN 2
              WHEN N'REVIEW_AFTER_LONGER_OBSERVATION' THEN 3
              WHEN N'KEEP_CONSTRAINT' THEN 4
              ELSE 5
          END
        , size_mb DESC
        , schema_name
        , table_name
        , index_name;
END
GO
Jak uruchomić

Najprościej:

EXEC dbo.usp_IndexAudit2016;

Wariant z innymi parametrami:

EXEC dbo.usp_IndexAudit2016
      @TopMissing = 100
    , @MinPageCountFrag = 500
    , @IncludeFrag = 1
    , @OnlyUserTables = 1;
Co czytać najpierw

Ja bym patrzył w tej kolejności:

Unused indexes
Szukaj:

REVIEW_UNUSED

duże size_mb

dużo user_updates

Duplicate indexes
Ten sam klucz = bardzo dobry kandydat do scalenia.

Overlapping indexes
Tu trzeba myśleć, nie rąbać toporem. Czasem węższy indeks nadal ma sens.

Missing indexes
Tylko jako sugestie. DMV lubią proponować indeksy „prawie takie same jak już masz”.

Largest indexes
Duży i nieużywany to klasyczny pasożyt.

Ważne pułapki

DMV usage stats resetują się po restarcie usługi SQL Server.
Czyli „0 seeks” po restarcie może znaczyć tylko tyle, że serwer niedawno wstał i jeszcze nie zdążył narozrabiać.

Missing index DMV nie wiedzą o wszystkim.
Nie rozumieją w pełni:

już istniejących podobnych indeksów,

kosztu utrzymania,

sensu biznesowego.