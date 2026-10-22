
Dzień dobry,

W związku ze zgłoszeniem dotyczącym fragmentacji indeksów w bazie danych **ws_HIRD** przeprowadziłem wstępną analizę techniczną środowiska SQL Server.

Zakres analizy obejmował:

- konfigurację instancji i bazy danych;
- stan fizyczny indeksów;
- statystyki wykorzystania indeksów;
- strukturę kluczy indeksów i kolumn INCLUDE;
- statystyki wykonywania zapytań dostępne w Query Store;
- analizę historycznych planów wykonania;
- identyfikację operatorów dostępu do danych.

Wszystkie przedstawione czynności diagnostyczne miały charakter wyłącznie odczytowy.

Poniżej przedstawiam wyniki wraz z wykorzystanymi zapytaniami T-SQL.

---

## 1. Konfiguracja środowiska

Przeprowadzono weryfikację konfiguracji bazy danych oraz mechanizmu Query Store.

**Zapytanie diagnostyczne:**

```sql
USE [ws_HIRD];
GO

SELECT
    @@SERVERNAME AS ServerName,
    DB_NAME() AS DatabaseName,
    SERVERPROPERTY('ProductVersion') AS SQLVersion,
    SERVERPROPERTY('ProductLevel') AS ProductLevel,
    d.compatibility_level AS CompatibilityLevel,
    d.is_read_committed_snapshot_on AS RCSI,
    d.snapshot_isolation_state_desc AS SnapshotIsolation,
    q.actual_state_desc AS QueryStoreState,
    q.desired_state_desc AS QueryStoreDesiredState,
    q.current_storage_size_mb AS QueryStoreSizeMB,
    q.max_storage_size_mb AS QueryStoreMaxMB
FROM sys.databases AS d
CROSS JOIN sys.database_query_store_options AS q
WHERE d.database_id = DB_ID();
```

**Uzyskane wyniki:**

| Parametr | Wartość |
|---|---|
| Baza danych | ws_HIRD |
| SQL Server | 2022 |
| Build | 16.0.4295.3 |
| Compatibility Level | 160 |
| RCSI | ON |
| Snapshot Isolation | OFF |
| Query Store | READ_WRITE |
| Query Store Size | 837 MB |
| Query Store Max | 1024 MB |

Query Store był aktywny i zajmował około 81,7% skonfigurowanej maksymalnej przestrzeni.

Wynik nie wskazuje samodzielnie na nieprawidłowość, jednak uzasadnia okresową kontrolę retencji i automatycznego czyszczenia danych Query Store.

---

## 2. Analiza statystyk wykorzystania indeksów

W pierwszym etapie przeanalizowano liczbę wierszy, rozmiary indeksów i statystyki ich wykorzystania.

**Zapytanie diagnostyczne:**

```sql
USE [ws_HIRD];
GO

SELECT
    SCHEMA_NAME(t.schema_id) AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.fill_factor AS FillFactor,
    i.is_primary_key AS IsPrimaryKey,
    i.is_unique AS IsUnique,
    SUM(p.rows) AS RowCount,
    SUM(p.used_page_count) * 8.0 / 1024 AS UsedMB,
    us.user_seeks AS UserSeeks,
    us.user_scans AS UserScans,
    us.user_lookups AS UserLookups,
    us.user_updates AS UserUpdates,
    us.last_user_seek AS LastSeek,
    us.last_user_scan AS LastScan
FROM sys.indexes AS i
JOIN sys.tables AS t
    ON t.object_id = i.object_id
JOIN sys.dm_db_partition_stats AS p
    ON p.object_id = i.object_id
   AND p.index_id = i.index_id
LEFT JOIN sys.dm_db_index_usage_stats AS us
    ON us.database_id = DB_ID()
   AND us.object_id = i.object_id
   AND us.index_id = i.index_id
WHERE i.index_id > 0
GROUP BY
    t.schema_id,
    t.name,
    i.name,
    i.type_desc,
    i.fill_factor,
    i.is_primary_key,
    i.is_unique,
    us.user_seeks,
    us.user_scans,
    us.user_lookups,
    us.user_updates,
    us.last_user_seek,
    us.last_user_scan
ORDER BY UsedMB DESC;
```

**Wyniki dla tabeli dbo.UserUnitRight:**

Tabela zawierała około **709 036 wierszy**.

Zaobserwowano:

- Około 3,89 mln operacji `user_seeks` na indeksie `PK_UserUnitRight`.
- Około 413 tys. operacji `user_seeks` dla `IX_UserUnitRight_UserIdUnitIdOpMask`.
- Około 274 tys. operacji `user_seeks` dla `IX_UserUnitRight_UnitId`.
- Około 323 tys. operacji `user_seeks` dla `UserUnitRight_UnitId`.
- Brak zarejestrowanych operacji `user_seeks` i `user_scans` dla `IX_UserUnitRight_UserIdLastModDate`.
- Około 1542 operacje `user_scans` dla `IX_UserUnitRight_UserId`.

Licznik `user_updates` dla analizowanych indeksów wynosił około 3,9 mln.

Wartości liczników DMV są zależne od okresu ich gromadzenia i nie stanowią pełnej historii wykorzystania indeksów.

Nie można na ich podstawie jednoznacznie uznać indeksu za zbędny.

---

## 3. Analiza fizyczna indeksów

Następnie wykonano analizę fragmentacji oraz gęstości stron przy użyciu `sys.dm_db_index_physical_stats`.

**Zapytanie diagnostyczne:**

```sql
USE [ws_HIRD];
GO

SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName,
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    ips.partition_number,
    ips.page_count AS PageCount,
    CAST(
        ips.page_count * 8.0 / 1024
        AS decimal(18,2)
    ) AS SizeMB,
    CAST(
        ips.avg_fragmentation_in_percent
        AS decimal(8,2)
    ) AS FragmentationPct,
    CAST(
        ips.avg_page_space_used_in_percent
        AS decimal(8,2)
    ) AS PageDensityPct,
    i.fill_factor AS FillFactor
FROM sys.indexes AS i
CROSS APPLY sys.dm_db_index_physical_stats(
    DB_ID(),
    i.object_id,
    i.index_id,
    NULL,
    'SAMPLED'
) AS ips
WHERE i.object_id = OBJECT_ID(N'dbo.UserUnitRight')
  AND i.index_id > 0
  AND ips.index_level = 0
  AND ips.alloc_unit_type_desc = 'IN_ROW_DATA'
ORDER BY ips.avg_fragmentation_in_percent DESC;
```

**Wyniki pomiarów:**

| Indeks | PageCount | Fragmentacja | Gęstość stron |
|---|---:|---:|---:|
| UserUnitRight_UnitId | 7 063 | 67,79% | 55,54% |
| IX_UserUnitRight_UnitId | 12 651 | 62,53% | 61,42% |
| IX_UserUnitRight_UserIdUnitIdOpMask | 13 434 | 49,04% | 63,29% |
| IX_UserUnitRight_UserId | 6 560 | 45,61% | 65,12% |
| IX_UserUnitRight_UserIdLastModDate | 7 013 | 44,55% | 65,88% |
| PK_UserUnitRight | 11 804 | 7,69% | 83,29% |

Analiza potwierdziła podwyższoną fragmentację pięciu indeksów nieklastrowanych.

Istotnym spostrzeżeniem jest również stosunkowo niska gęstość stron w zakresie 55–66%.

Może to prowadzić do zwiększonego zapotrzebowania na pamięć buforową oraz dodatkowych odczytów logicznych.

Nie stanowi jednak jednoznacznego dowodu pogorszenia wydajności.

---

## 4. Analiza definicji indeksów

W celu oceny potencjalnego nakładania się indeksów przeanalizowano ich klucze oraz kolumny INCLUDE.

**Zapytanie diagnostyczne:**

```sql
USE [ws_HIRD];
GO

SELECT
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ic.key_ordinal AS KeyOrdinal,
    c.name AS ColumnName,
    ic.is_included_column AS IsIncluded,
    ic.is_descending_key AS IsDescending
FROM sys.indexes AS i
JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id
   AND ic.index_id = i.index_id
JOIN sys.columns AS c
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID(N'dbo.UserUnitRight')
ORDER BY
    i.name,
    ic.is_included_column,
    ic.key_ordinal,
    ic.index_column_id;
```

**Wyniki analizy:**

Zidentyfikowano indeksy rozpoczynające się od tych samych kolumn klucza, szczególnie `UnitId` i `UserId`.

Występują różnice w kolejności kolejnych kolumn klucza oraz kolumnach INCLUDE.

Może to świadczyć o częściowym pokrywaniu się funkcjonalności indeksów.

Nie można jednak rekomendować ich konsolidacji bez analizy zapytań, planów wykonania i całego wzorca obciążenia tabeli.

---

## 5. Analiza historycznych statystyk Query Store

W celu identyfikacji zapytań generujących największe obciążenie przeanalizowano statystyki dotyczące tabeli `UserUnitRight`.

**Zapytanie diagnostyczne:**

```sql
USE [ws_HIRD];
GO

DECLARE @From datetimeoffset =
    TODATETIMEOFFSET(
        DATEADD(HOUR, -24, SYSDATETIME()),
        DATEPART(TZOFFSET, SYSDATETIMEOFFSET())
    );

WITH QueryStats AS
(
    SELECT
        q.query_id,
        p.plan_id,
        SUM(rs.count_executions) AS Executions,

        SUM(
            CONVERT(float, rs.avg_duration)
            * rs.count_executions
        ) / 1000.0 AS TotalDurationMs,

        SUM(
            CONVERT(float, rs.avg_cpu_time)
            * rs.count_executions
        ) / 1000.0 AS TotalCpuMs,

        SUM(
            CONVERT(float, rs.avg_logical_io_reads)
            * rs.count_executions
        ) AS TotalLogicalReads,

        SUM(
            CONVERT(float, rs.avg_rowcount)
            * rs.count_executions
        ) AS TotalRows,

        MAX(rs.max_rowcount) AS MaxRows,

        MAX(rsi.end_time) AS LastInterval
    FROM sys.query_store_query AS q
    JOIN sys.query_store_plan AS p
        ON p.query_id = q.query_id
    JOIN sys.query_store_runtime_stats AS rs
        ON rs.plan_id = p.plan_id
    JOIN sys.query_store_runtime_stats_interval AS rsi
        ON rsi.runtime_stats_interval_id =
           rs.runtime_stats_interval_id
    WHERE rsi.end_time > @From
      AND rs.execution_type = 0
    GROUP BY
        q.query_id,
        p.plan_id
)
SELECT TOP (30)
    qs.query_id,
    qs.plan_id,
    qs.Executions,

    CAST(
        qs.TotalDurationMs /
        NULLIF(qs.Executions, 0)
        AS decimal(18,2)
    ) AS AvgDurationMs,

    CAST(
        qs.TotalCpuMs /
        NULLIF(qs.Executions, 0)
        AS decimal(18,2)
    ) AS AvgCpuMs,

    CAST(
        qs.TotalLogicalReads /
        NULLIF(qs.Executions, 0)
        AS decimal(18,2)
    ) AS AvgLogicalReads,

    CAST(
        qs.TotalRows /
        NULLIF(qs.Executions, 0)
        AS decimal(18,2)
    ) AS AvgRows,

    qs.MaxRows,
    qs.TotalLogicalReads,
    qs.LastInterval,
    LEFT(qt.query_sql_text, 2000) AS QueryText
FROM QueryStats AS qs
JOIN sys.query_store_query AS q
    ON q.query_id = qs.query_id
JOIN sys.query_store_query_text AS qt
    ON qt.query_text_id = q.query_text_id
WHERE qt.query_sql_text LIKE '%UserUnitRight%'
ORDER BY qs.TotalLogicalReads DESC
OPTION (RECOMPILE);
```

**Wyniki:**

Zidentyfikowano zapytanie o identyfikatorze:

`query_id = 10902483`

Zapytanie generowało wysoką liczbę odczytów logicznych, sięgającą około 200 tys. stron na wykonanie.

Query Store przechowywał 47 historycznych planów wykonania tego zapytania.

---

## 6. Analiza aktywności planów wykonania

Sprawdzono, które plany były wykorzystywane w ostatnich 24 godzinach.

**Zapytanie diagnostyczne:**

```sql
USE [ws_HIRD];
GO

SELECT
    p.plan_id,
    p.is_forced_plan,
    p.last_execution_time,
    SUM(rs.count_executions) AS Executions,
    CAST(
        SUM(rs.avg_duration * rs.count_executions)
        / NULLIF(SUM(rs.count_executions), 0) / 1000.0
        AS decimal(18,2)
    ) AS AvgDurationMs,
    CAST(
        SUM(rs.avg_logical_io_reads * rs.count_executions)
        / NULLIF(SUM(rs.count_executions), 0)
        AS decimal(18,2)
    ) AS AvgLogicalReads,
    CAST(
        SUM(rs.avg_rowcount * rs.count_executions)
        / NULLIF(SUM(rs.count_executions), 0)
        AS decimal(18,2)
    ) AS AvgRows
FROM sys.query_store_plan AS p
JOIN sys.query_store_runtime_stats AS rs
    ON rs.plan_id = p.plan_id
JOIN sys.query_store_runtime_stats_interval AS rsi
    ON rsi.runtime_stats_interval_id =
       rs.runtime_stats_interval_id
WHERE p.query_id = 10902483
  AND rsi.end_time >=
      DATEADD(HOUR, -24, SYSUTCDATETIME())
  AND rs.execution_type = 0
GROUP BY
    p.plan_id,
    p.is_forced_plan,
    p.last_execution_time
ORDER BY Executions DESC;
```

**Wyniki:**

| Plan ID | Wykonania | AvgDurationMs | AvgLogicalReads |
|---|---:|---:|---:|
| 621527 | 7 330 | 420,32 | 201 453 |
| 630990 | 4 827 | 456,93 | 196 250 |
| 631566 | 387 | 290,55 | 191 399 |
| 635210 | 136 | 383,04 | 184 984 |
| 635188 | 13 | 192,96 | 178 818 |
| 635198 | 12 | 203,69 | 179 390 |

Sześć planów wykazywało aktywność w analizowanym okresie.

Dwa najczęściej wykorzystywane plany miały łącznie 12 157 wykonań.

Pomimo różnic w strukturach planów liczba odczytów logicznych była relatywnie zbliżona.

Nie potwierdzono jednoznacznej regresji wydajności wynikającej z wyboru konkretnego planu.

---

## 7. Analiza hashy i metadanych planów

W kolejnym kroku porównano metadane sześciu planów wykonania.

**Zapytanie diagnostyczne:**

```sql
USE [ws_HIRD];
GO

SELECT
    plan_id,
    CONVERT(varchar(34), query_plan_hash, 1)
        AS QueryPlanHash,
    is_parallel_plan AS IsParallel,
    is_forced_plan AS IsForced,
    compatibility_level AS CompatibilityLevel,
    last_compile_start_time AS LastCompile,
    last_execution_time AS LastExecution
FROM sys.query_store_plan
WHERE plan_id IN
(
    621527,
    630990,
    631566,
    635210,
    635188,
    635198
)
ORDER BY plan_id;
```

Wyniki wykazały:

- Sześć różnych wartości `query_plan_hash`.
- Równoległość wszystkich planów.
- Brak wymuszonych planów.
- Compatibility Level 160.

Następnie sprawdzono typy planów.

**Zapytanie diagnostyczne:**

```sql
USE [ws_HIRD];
GO

SELECT
    plan_id,
    plan_type_desc,
    count_compiles,
    is_parallel_plan,
    last_compile_start_time,
    last_execution_time
FROM sys.query_store_plan
WHERE query_id = 10902483
  AND plan_id IN
  (
      621527,
      630990,
      631566,
      635210,
      635188,
      635198
  )
ORDER BY plan_id;
```

Wszystkie sześć planów miało typ `Compiled Plan`.

Liczba kompilacji wynosiła:

| Plan ID | Count Compiles |
|---|---:|
| 621527 | 49 |
| 630990 | 20 |
| 631566 | 22 |
| 635188 | 2 |
| 635198 | 1 |
| 635210 | 2 |

Nie znaleziono w tym zestawie planów oznaczonych jako `Dispatcher Plan` ani `Query Variant Plan`.

---

## 8. Analiza wykorzystania indeksów w planach wykonania

Dla dwóch najczęściej wykorzystywanych planów wykonania przeanalizowano operatory dostępu do indeksów.

**Zapytanie diagnostyczne:**

```sql
USE [ws_HIRD];
GO

;WITH XMLNAMESPACES (
    'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
    AS sp
)
SELECT
    p.plan_id,
    n.value('@PhysicalOp', 'nvarchar(100)')
        AS PhysicalOperator,
    n.value('@LogicalOp', 'nvarchar(100)')
        AS LogicalOperator,
    n.value(
        '(sp:IndexScan/sp:Object/@Schema)[1]',
        'nvarchar(128)'
    ) AS SchemaName,
    n.value(
        '(sp:IndexScan/sp:Object/@Table)[1]',
        'nvarchar(128)'
    ) AS TableName,
    n.value(
        '(sp:IndexScan/sp:Object/@Index)[1]',
        'nvarchar(128)'
    ) AS IndexName,
    n.value('@EstimateRows', 'float')
        AS EstimatedRows
FROM sys.query_store_plan AS p
CROSS APPLY
(
    SELECT TRY_CONVERT(xml, p.query_plan) AS PlanXML
) AS x
CROSS APPLY x.PlanXML.nodes(
    '//sp:RelOp[sp:IndexScan]'
) AS T(n)
WHERE p.plan_id IN (621527, 630990)
ORDER BY
    p.plan_id,
    TableName,
    IndexName;
```

**Wyniki:**

Oba plany korzystały z indeksu:

`IX_UserUnitRight_UserIdUnitIdOpMask`

Operator dostępu:

`Index Seek`

Estymowana liczba wierszy:

| Plan ID | Estimated Rows |
|---|---:|
| 621527 | 369,842 |
| 630990 | 256,758 |

Plany zawierały również operacje dostępu do wielu innych tabel, m.in. `Unit`, `ConfigUnit`, `ConfigFlow`, `Membership`, `GroupUnitRight`.

Zaobserwowano skanowania indeksów tabeli `Unit`, z estymacjami dochodzącymi do około 1,1 mln wierszy.

Sama obecność operatora `Index Scan` nie świadczy jednak o nieprawidłowości. Ocena wymaga znajomości warunków zapytania, liczby przetwarzanych wierszy oraz kosztów pozostałych operatorów.

---

## 9. Podsumowanie ustaleń

Przeprowadzona analiza pozwoliła stwierdzić, że:

1. W tabeli `dbo.UserUnitRight` występuje podwyższona fragmentacja części indeksów nieklastrowanych.
2. Zaobserwowano stosunkowo niską gęstość stron indeksów.
3. Niektóre indeksy mają wspólne kolumny początkowe kluczy, co uzasadnia ewentualną analizę redundancji.
4. Query Store wykazał istnienie zapytania generującego znaczną liczbę odczytów logicznych.
5. Dwa najczęściej wykonywane plany tego zapytania wykorzystują ten sam indeks tabeli `UserUnitRight` z operatorem `Index Seek`.
6. Nie potwierdzono, że fragmentacja analizowanych indeksów jest przyczyną wysokiej liczby odczytów logicznych.
7. Na podstawie dostępnych pomiarów nie można jednoznacznie stwierdzić, że w bazie występuje problem wydajnościowy wynikający z fragmentacji.

## 10. Rekomendacje

Rekomenduję wykonanie uzgodnionych czynności utrzymaniowych dotyczących wskazanych indeksów, z zachowaniem standardowych zasad bezpieczeństwa środowiska produkcyjnego.

Po wykonaniu operacji warto ponownie zmierzyć fragmentację oraz gęstość stron w celu udokumentowania jej efektu.

Dodatkowa optymalizacja zapytań, analiza redundancji indeksów i szczegółowa analiza planów wykonania powinny być realizowane w ramach odrębnie uzgodnionego zakresu prac.

## 11. Zakres i ograniczenia analizy

Przedstawione działania miały charakter wstępnej diagnostyki technicznej.

Analiza nie stanowi pełnego audytu wydajności bazy danych `ws_HIRD`.

Nie przeprowadzano zmian konfiguracji instancji, modyfikacji indeksów ani wymuszania planów wykonania w ramach opisanych czynności diagnostycznych.

Nie przeprowadzono również pełnej analizy rzeczywistych planów wykonania wszystkich zidentyfikowanych zapytań.

**Wniosek końcowy:**

Przeprowadzone pomiary potwierdzają fragmentację wybranych indeksów, ale nie wykazują bezpośredniego związku pomiędzy tą fragmentacją a problemami wydajnościowymi bazy danych.

Dalsze działania optymalizacyjne wymagają określenia konkretnego problemu, jego wpływu na działanie systemu oraz uzgodnienia zakresu dodatkowej diagnostyki.

Z poważaniem
