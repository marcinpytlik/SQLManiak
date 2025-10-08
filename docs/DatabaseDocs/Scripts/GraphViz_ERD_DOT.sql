-- Generate GraphViz DOT for ERD (tables + FKs). Use result text as ERD.dot
DECLARE @dot NVARCHAR(MAX) = N'digraph ERD { rankdir=LR; node [shape=record]; ';

-- nodes
SELECT @dot += 
    QUOTENAME(s.name + '.' + t.name, '"') + ' [label="' + s.name + '.' + t.name + '"]; '
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id;

-- edges
SELECT @dot += 
    QUOTENAME(schChild.name + '.' + tChild.name, '"') + ' -> ' + QUOTENAME(schParent.name + '.' + tParent.name, '"') +
    ' [label="' + fk.name + '"]; '
FROM sys.foreign_keys fk
JOIN sys.tables tChild   ON tChild.object_id = fk.parent_object_id
JOIN sys.schemas schChild ON schChild.schema_id = tChild.schema_id
JOIN sys.tables tParent  ON tParent.object_id = fk.referenced_object_id
JOIN sys.schemas schParent ON schParent.schema_id = tParent.schema_id;

SET @dot += ' }';
SELECT @dot AS ERD_DOT;
