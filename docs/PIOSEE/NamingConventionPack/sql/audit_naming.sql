/*
Audit: Naming convention compliance (read-only)
SQL Server 2017+ (STRING_AGG używane w części zapytań)
*/
SET NOCOUNT ON;

------------------------------
-- 1) Obiekty: widoki/procki/funkcje/synonimy/seq
------------------------------
;WITH objs AS (
    SELECT s.name AS [schema], o.name, o.type, o.type_desc
    FROM sys.objects o
    JOIN sys.schemas s ON s.schema_id = o.schema_id
    WHERE o.is_ms_shipped = 0
      AND o.type IN ('V','P','FN','IF','TF','SQ','SN','TR') -- view/proc/functions/seq/synonym/trigger
)
SELECT type_desc, [schema], name AS object_name
     , CASE 
         WHEN type = 'V'  AND name NOT LIKE 'vw\_%' ESCAPE '\' THEN 'Expected prefix: vw_'
         WHEN type = 'P'  AND name NOT LIKE 'usp\_%' ESCAPE '\' THEN 'Expected prefix: usp_ (avoid sp_)'
         WHEN type = 'FN' AND name NOT LIKE 'ufn\_%' ESCAPE '\' THEN 'Expected prefix: ufn_'
         WHEN type IN('IF','TF') AND name NOT LIKE 'utvf\_%' ESCAPE '\' THEN 'Expected prefix: utvf_'
         WHEN type = 'TR' AND name NOT LIKE 'trg\_%' ESCAPE '\' THEN 'Expected prefix: trg_'
         WHEN type = 'SQ' AND name NOT LIKE 'seq\_%' ESCAPE '\' THEN 'Expected prefix: seq_'
         WHEN type = 'SN' AND name NOT LIKE 'syn\_%' ESCAPE '\' THEN 'Expected prefix: syn_'
         ELSE NULL END AS issue
FROM objs
WHERE (type = 'V'  AND name NOT LIKE 'vw\_%' ESCAPE '\')
   OR (type = 'P'  AND name NOT LIKE 'usp\_%' ESCAPE '\')
   OR (type = 'FN' AND name NOT LIKE 'ufn\_%' ESCAPE '\')
   OR (type IN('IF','TF') AND name NOT LIKE 'utvf\_%' ESCAPE '\')
   OR (type = 'TR' AND name NOT LIKE 'trg\_%' ESCAPE '\')
   OR (type = 'SQ' AND name NOT LIKE 'seq\_%' ESCAPE '\')
   OR (type = 'SN' AND name NOT LIKE 'syn\_%' ESCAPE '\')
ORDER BY type_desc, [schema], object_name;

------------------------------
-- 2) Constrainty
------------------------------
-- PK
SELECT 'PK' AS type, s.name AS [schema], t.name AS [table], kc.name AS constraint_name,
       CONCAT('PK_', s.name, '_', t.name) AS expected_name
FROM sys.key_constraints kc
JOIN sys.tables t ON t.object_id = kc.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE kc.type = 'PK'
  AND kc.name <> CONCAT('PK_', s.name, '_', t.name);

-- UQ
SELECT 'UQ' AS type, s.name AS [schema], t.name AS [table], kc.name AS constraint_name,
       LEFT(CONCAT('UQ_', s.name, '_', t.name, '_',
                   REPLACE(STRING_AGG(c.name, '_') WITHIN GROUP (ORDER BY ic.key_ordinal), ' ', '')) ,128) AS expected_name
FROM sys.key_constraints kc
JOIN sys.tables t ON t.object_id = kc.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.index_columns ic ON ic.object_id = t.object_id AND ic.index_id = kc.unique_index_id
JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = ic.column_id
WHERE kc.type = 'UQ'
GROUP BY s.name, t.name, kc.name
HAVING kc.name <> LEFT(CONCAT('UQ_', s.name, '_', t.name, '_',
                   REPLACE(STRING_AGG(c.name, '_') WITHIN GROUP (ORDER BY ic.key_ordinal), ' ', '')) ,128);

-- CHECK
SELECT 'CK' AS type, s.name AS [schema], t.name AS [table], cc.name AS constraint_name,
       LEFT(CONCAT('CK_', s.name, '_', t.name, '_', REPLACE(c.name,' ','_')), 128) AS expected_name
FROM sys.check_constraints cc
JOIN sys.tables t ON t.object_id = cc.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
LEFT JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = cc.parent_column_id
WHERE cc.name NOT LIKE 'CK\_%' ESCAPE '\' 
   OR cc.name NOT LIKE CONCAT('CK_', s.name, '_', t.name, '%');

-- DEFAULT
SELECT 'DF' AS type, s.name AS [schema], t.name AS [table], dc.name AS constraint_name,
       LEFT(CONCAT('DF_', s.name, '_', t.name, '_', c.name),128) AS expected_name
FROM sys.default_constraints dc
JOIN sys.tables t ON t.object_id = dc.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = dc.parent_column_id
WHERE dc.name <> LEFT(CONCAT('DF_', s.name, '_', t.name, '_', c.name),128);

-- FK
SELECT 'FK' AS type, sch_child.name AS child_schema, t_child.name AS child_table, fk.name AS constraint_name,
       CONCAT('FK_', sch_child.name, '_', t_child.name, '__', sch_parent.name, '_', t_parent.name) AS expected_name
FROM sys.foreign_keys fk
JOIN sys.tables t_child ON t_child.object_id = fk.parent_object_id
JOIN sys.schemas sch_child ON sch_child.schema_id = t_child.schema_id
JOIN sys.tables t_parent ON t_parent.object_id = fk.referenced_object_id
JOIN sys.schemas sch_parent ON sch_parent.schema_id = t_parent.schema_id
WHERE fk.name <> CONCAT('FK_', sch_child.name, '_', t_child.name, '__', sch_parent.name, '_', t_parent.name);

------------------------------
-- 3) Indeksy
------------------------------
;WITH idx AS (
  SELECT s.name AS [schema], t.name AS [table], i.name AS index_name, i.is_unique, i.index_id,
         STRING_AGG(CASE WHEN ic.is_included_column = 0 THEN c.name END, '_' ) 
             WITHIN GROUP (ORDER BY ic.key_ordinal) AS key_cols,
         STRING_AGG(CASE WHEN ic.is_included_column = 1 THEN c.name END, '_' )
             WITHIN GROUP (ORDER BY c.column_id) AS inc_cols
  FROM sys.indexes i
  JOIN sys.tables t ON t.object_id = i.object_id
  JOIN sys.schemas s ON s.schema_id = t.schema_id
  JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
  JOIN sys.columns c ON c.object_id = i.object_id AND c.column_id = ic.column_id
  WHERE i.index_id > 0 AND i.is_hypothetical = 0 AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
  GROUP BY s.name, t.name, i.name, i.is_unique, i.index_id
)
SELECT 'INDEX' AS type, [schema], [table], index_name,
       LEFT(
         CASE WHEN is_unique = 1 
              THEN CONCAT('IXU_', [schema], '_', [table], '_', REPLACE(COALESCE(key_cols,''),' ','_'))
              ELSE CONCAT('IX_',  [schema], '_', [table], '_', REPLACE(COALESCE(key_cols,''),' ','_'))
         END +
         CASE WHEN inc_cols IS NOT NULL THEN CONCAT('_INC_', REPLACE(inc_cols,' ','_')) ELSE '' END
       ,128) AS expected_name
FROM idx
WHERE index_name <> LEFT(
         CASE WHEN is_unique = 1 
              THEN CONCAT('IXU_', [schema], '_', [table], '_', REPLACE(COALESCE(key_cols,''),' ','_'))
              ELSE CONCAT('IX_',  [schema], '_', [table], '_', REPLACE(COALESCE(key_cols,''),' ','_'))
         END +
         CASE WHEN inc_cols IS NOT NULL THEN CONCAT('_INC_', REPLACE(inc_cols,' ','_')) ELSE '' END
       ,128)
ORDER BY [schema],[table],index_name;

------------------------------
-- 4) Kolumny PK/FK — szybka kontrola nazewnictwa
------------------------------
-- PK: Id albo {Table}Id
SELECT s.name AS [schema], t.name AS [table], c.name AS column_name
FROM sys.key_constraints kc
JOIN sys.tables t ON t.object_id = kc.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.index_columns ic ON ic.object_id = t.object_id AND ic.index_id = kc.unique_index_id AND ic.key_ordinal = 1
JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = ic.column_id
WHERE kc.type = 'PK'
  AND c.name NOT IN ('Id', t.name + 'Id');

-- FK: {Parent}Id
SELECT sch_child.name AS child_schema, t_child.name AS child_table, c_child.name AS column_name, 'Expect suffix: Id' AS note
FROM sys.foreign_key_columns fkc
JOIN sys.tables t_child ON t_child.object_id = fkc.parent_object_id
JOIN sys.schemas sch_child ON sch_child.schema_id = t_child.schema_id
JOIN sys.columns c_child ON c_child.object_id = fkc.parent_object_id AND c_child.column_id = fkc.parent_column_id
JOIN sys.tables t_parent ON t_parent.object_id = fkc.referenced_object_id
WHERE c_child.name NOT IN (t_parent.name + 'Id');


------------------------------
-- 5) SQL Agent
------------------------------
SELECT 'JOB' AS kind, j.name
FROM msdb.dbo.sysjobs j
WHERE j.name NOT LIKE 'JOB\_%' ESCAPE '\';

SELECT 'STEP' AS kind, j.name AS job_name, js.step_id, js.step_name
FROM msdb.dbo.sysjobsteps js
JOIN msdb.dbo.sysjobs j ON j.job_id = js.job_id
WHERE js.step_name NOT LIKE 'STEP\_%' ESCAPE '\';

SELECT 'SCHEDULE' AS kind, s.name
FROM msdb.dbo.sysschedules s
WHERE s.name NOT LIKE 'SCH\_%' ESCAPE '\';
