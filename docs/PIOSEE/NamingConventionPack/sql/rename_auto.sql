/*
Auto-rename to convention
- Parametr APPLY: 0 = PRINT only, 1 = EXEC
- Długość nazwy docelowej ograniczona do 128
*/
:setvar APPLY 0
DECLARE @APPLY bit = TRY_CONVERT(bit, '$(APPLY)');
IF @APPLY IS NULL SET @APPLY = 0;

SET NOCOUNT ON;

----------------------------------------------------------------
-- Helper: sanitize to [A-Za-z0-9_], cut to 128
----------------------------------------------------------------
DECLARE @SanitizePattern varchar(100) = '%[^0-9A-Za-z_]%';

----------------------------------------------------------------
-- 1) PK
----------------------------------------------------------------
;WITH pk AS (
  SELECT s.name AS [schema], t.name AS [table], kc.name AS old_name,
         CONCAT('PK_', s.name, '_', t.name) AS expected
  FROM sys.key_constraints kc
  JOIN sys.tables t ON t.object_id = kc.parent_object_id
  JOIN sys.schemas s ON s.schema_id = t.schema_id
  WHERE kc.type = 'PK'
)
SELECT * INTO #todo_pk FROM pk
WHERE old_name <> expected;

DECLARE @old sysname, @new sysname, @sql nvarchar(4000);
WHILE EXISTS (SELECT 1 FROM #todo_pk)
BEGIN
  SELECT TOP(1) @old = old_name, @new = expected FROM #todo_pk;
  SET @new = LEFT(@new,128);
  IF @APPLY = 1
       EXEC sp_rename @objname = QUOTENAME(@old), @newname = @new, @objtype = 'OBJECT'; -- constraint is OBJECT
  ELSE PRINT CONCAT('EXEC sp_rename ', QUOTENAME(@old, ''''), ', ', QUOTENAME(@new, ''''), ', ''OBJECT'';');
  DELETE FROM #todo_pk WHERE old_name = @old;
END

----------------------------------------------------------------
-- 2) UNIQUE constraints
----------------------------------------------------------------
;WITH uq AS (
  SELECT s.name AS [schema], t.name AS [table], kc.name AS old_name,
         LEFT(CONCAT('UQ_', s.name, '_', t.name, '_',
              REPLACE(STRING_AGG(c.name, '_') WITHIN GROUP(ORDER BY ic.key_ordinal),' ','_')),128) AS expected
  FROM sys.key_constraints kc
  JOIN sys.tables t ON t.object_id = kc.parent_object_id
  JOIN sys.schemas s ON s.schema_id = t.schema_id
  JOIN sys.index_columns ic ON ic.object_id = t.object_id AND ic.index_id = kc.unique_index_id
  JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = ic.column_id
  WHERE kc.type = 'UQ'
  GROUP BY s.name, t.name, kc.name
)
SELECT * INTO #todo_uq FROM uq WHERE old_name <> expected;

WHILE EXISTS (SELECT 1 FROM #todo_uq)
BEGIN
  SELECT TOP(1) @old = old_name, @new = expected FROM #todo_uq;
  SET @new = LEFT(@new,128);
  IF @APPLY = 1 EXEC sp_rename @objname = QUOTENAME(@old), @newname = @new, @objtype = 'OBJECT';
  ELSE PRINT CONCAT('EXEC sp_rename ', QUOTENAME(@old, ''''), ', ', QUOTENAME(@new, ''''), ', ''OBJECT'';');
  DELETE FROM #todo_uq WHERE old_name = @old;
END

----------------------------------------------------------------
-- 3) DEFAULT constraints
----------------------------------------------------------------
;WITH dfx AS (
  SELECT s.name AS [schema], t.name AS [table], c.name AS col, dc.name AS old_name,
         LEFT(CONCAT('DF_', s.name, '_', t.name, '_', c.name),128) AS expected
  FROM sys.default_constraints dc
  JOIN sys.tables t ON t.object_id = dc.parent_object_id
  JOIN sys.schemas s ON s.schema_id = t.schema_id
  JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = dc.parent_column_id
)
SELECT * INTO #todo_df FROM dfx WHERE old_name <> expected;

WHILE EXISTS (SELECT 1 FROM #todo_df)
BEGIN
  SELECT TOP(1) @old = old_name, @new = expected FROM #todo_df;
  SET @new = LEFT(@new,128);
  IF @APPLY = 1 EXEC sp_rename @objname = QUOTENAME(@old), @newname = @new, @objtype = 'OBJECT';
  ELSE PRINT CONCAT('EXEC sp_rename ', QUOTENAME(@old, ''''), ', ', QUOTENAME(@new, ''''), ', ''OBJECT'';');
  DELETE FROM #todo_df WHERE old_name = @old;
END

----------------------------------------------------------------
-- 4) CHECK constraints
----------------------------------------------------------------
;WITH ck AS (
  SELECT s.name AS [schema], t.name AS [table], COALESCE(c.name,'_Rule') AS col, cc.name AS old_name,
         LEFT(CONCAT('CK_', s.name, '_', t.name, '_', REPLACE(COALESCE(c.name,'Rule'),' ','_')),128) AS expected
  FROM sys.check_constraints cc
  JOIN sys.tables t ON t.object_id = cc.parent_object_id
  JOIN sys.schemas s ON s.schema_id = t.schema_id
  LEFT JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = cc.parent_column_id
)
SELECT * INTO #todo_ck FROM ck WHERE old_name <> expected;

WHILE EXISTS (SELECT 1 FROM #todo_ck)
BEGIN
  SELECT TOP(1) @old = old_name, @new = expected FROM #todo_ck;
  SET @new = LEFT(@new,128);
  IF @APPLY = 1 EXEC sp_rename @objname = QUOTENAME(@old), @newname = @new, @objtype = 'OBJECT';
  ELSE PRINT CONCAT('EXEC sp_rename ', QUOTENAME(@old, ''''), ', ', QUOTENAME(@new, ''''), ', ''OBJECT'';');
  DELETE FROM #todo_ck WHERE old_name = @old;
END

----------------------------------------------------------------
-- 5) FOREIGN KEYS
----------------------------------------------------------------
;WITH fk AS (
  SELECT sch_c.name AS child_schema, t_c.name AS child_table, fk.name AS old_name,
         LEFT(CONCAT('FK_', sch_c.name, '_', t_c.name, '__', sch_p.name, '_', t_p.name),128) AS expected
  FROM sys.foreign_keys fk
  JOIN sys.tables t_c ON t_c.object_id = fk.parent_object_id
  JOIN sys.schemas sch_c ON sch_c.schema_id = t_c.schema_id
  JOIN sys.tables t_p ON t_p.object_id = fk.referenced_object_id
  JOIN sys.schemas sch_p ON sch_p.schema_id = t_p.schema_id
)
SELECT * INTO #todo_fk FROM fk WHERE old_name <> expected;

WHILE EXISTS (SELECT 1 FROM #todo_fk)
BEGIN
  SELECT TOP(1) @old = old_name, @new = expected FROM #todo_fk;
  SET @new = LEFT(@new,128);
  IF @APPLY = 1 EXEC sp_rename @objname = QUOTENAME(@old), @newname = @new, @objtype = 'OBJECT';
  ELSE PRINT CONCAT('EXEC sp_rename ', QUOTENAME(@old, ''''), ', ', QUOTENAME(@new, ''''), ', ''OBJECT'';');
  DELETE FROM #todo_fk WHERE old_name = @old;
END

----------------------------------------------------------------
-- 6) INDEXES (non PK/UQ)
----------------------------------------------------------------
;WITH idx AS (
  SELECT s.name AS [schema], t.name AS [table], i.name AS old_name, i.is_unique,
         LEFT(
           CASE WHEN i.is_unique = 1 
                THEN CONCAT('IXU_', s.name, '_', t.name, '_', REPLACE(STRING_AGG(CASE WHEN ic.is_included_column = 0 THEN c.name END,'_') WITHIN GROUP(ORDER BY ic.key_ordinal),' ','_'))
                ELSE CONCAT('IX_',  s.name, '_', t.name, '_', REPLACE(STRING_AGG(CASE WHEN ic.is_included_column = 0 THEN c.name END,'_') WITHIN GROUP(ORDER BY ic.key_ordinal),' ','_'))
           END +
           CASE WHEN COUNT(CASE WHEN ic.is_included_column = 1 THEN 1 END) > 0 
                THEN CONCAT('_INC_', REPLACE(STRING_AGG(CASE WHEN ic.is_included_column = 1 THEN c.name END,'_') WITHIN GROUP(ORDER BY c.column_id),' ','_'))
                ELSE '' END
           ,128) AS expected
  FROM sys.indexes i
  JOIN sys.tables t ON t.object_id = i.object_id
  JOIN sys.schemas s ON s.schema_id = t.schema_id
  JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
  JOIN sys.columns c ON c.object_id = i.object_id AND c.column_id = ic.column_id
  WHERE i.index_id > 0 AND i.is_hypothetical = 0 AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
  GROUP BY s.name, t.name, i.name, i.is_unique
)
SELECT * INTO #todo_ix FROM idx WHERE old_name <> expected;

WHILE EXISTS (SELECT 1 FROM #todo_ix)
BEGIN
  SELECT TOP(1) @old = old_name, @new = expected FROM #todo_ix;
  SET @new = LEFT(@new,128);
  IF @APPLY = 1 EXEC sp_rename @objname = QUOTENAME(@old), @newname = @new, @objtype = 'INDEX';
  ELSE PRINT CONCAT('EXEC sp_rename ', QUOTENAME(@old, ''''), ', ', QUOTENAME(@new, ''''), ', ''INDEX'';');
  DELETE FROM #todo_ix WHERE old_name = @old;
END

----------------------------------------------------------------
-- 7) Objects (views/procs/functions/triggers/synonyms/sequences) — prefix fix
----------------------------------------------------------------
;WITH objs AS (
    SELECT s.name AS [schema], o.name AS old_name, o.object_id, o.type, o.type_desc,
           CASE 
             WHEN o.type = 'V'  AND o.name NOT LIKE 'vw[_]%'   THEN CONCAT('vw_', o.name)
             WHEN o.type = 'P'  AND o.name NOT LIKE 'usp[_]%'  THEN CONCAT('usp_', o.name)
             WHEN o.type = 'FN' AND o.name NOT LIKE 'ufn[_]%'  THEN CONCAT('ufn_', o.name)
             WHEN o.type IN('IF','TF') AND o.name NOT LIKE 'utvf[_]%' THEN CONCAT('utvf_', o.name)
             WHEN o.type = 'TR' AND o.name NOT LIKE 'trg[_]%'  THEN CONCAT('trg_', o.name)
             WHEN o.type = 'SQ' AND o.name NOT LIKE 'seq[_]%'  THEN CONCAT('seq_', o.name)
             WHEN o.type = 'SN' AND o.name NOT LIKE 'syn[_]%'  THEN CONCAT('syn_', o.name)
             ELSE NULL END AS expected
    FROM sys.objects o
    JOIN sys.schemas s ON s.schema_id = o.schema_id
    WHERE o.is_ms_shipped = 0
      AND o.type IN ('V','P','FN','IF','TF','SQ','SN','TR')
)
SELECT * INTO #todo_obj FROM objs WHERE expected IS NOT NULL;

WHILE EXISTS (SELECT 1 FROM #todo_obj)
BEGIN
  SELECT TOP(1) @old = old_name, @new = expected FROM #todo_obj;
  SET @new = LEFT(@new,128);
  IF @APPLY = 1 EXEC sp_rename @objname = @old, @newname = @new; -- same schema
  ELSE PRINT CONCAT('EXEC sp_rename ', QUOTENAME(@old, ''''), ', ', QUOTENAME(@new, ''''), ';');
  DELETE FROM #todo_obj WHERE old_name = @old;
END

PRINT 'Done. APPLY=' + CAST(@APPLY AS varchar(5));
