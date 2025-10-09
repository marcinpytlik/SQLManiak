-- Foreign keys and referenced columns
SELECT
    schChild.name AS schema_name,
    tChild.name   AS table_name,
    fk.name       AS fk_name,
    schParent.name AS ref_schema_name,
    tParent.name   AS ref_table_name,
    STUFF((SELECT ',' + cChild.name
           FROM sys.foreign_key_columns fkc2
           JOIN sys.columns cChild ON cChild.object_id = fkc2.parent_object_id AND cChild.column_id = fkc2.parent_column_id
           WHERE fkc2.constraint_object_id = fk.object_id
           ORDER BY fkc2.constraint_column_id
           FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'),1,1,'') AS fk_columns,
    STUFF((SELECT ',' + cParent.name
           FROM sys.foreign_key_columns fkc2
           JOIN sys.columns cParent ON cParent.object_id = fkc2.referenced_object_id AND cParent.column_id = fkc2.referenced_column_id
           WHERE fkc2.constraint_object_id = fk.object_id
           ORDER BY fkc2.constraint_column_id
           FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'),1,1,'') AS ref_columns
FROM sys.foreign_keys fk
JOIN sys.tables tChild   ON tChild.object_id = fk.parent_object_id
JOIN sys.schemas schChild ON schChild.schema_id = tChild.schema_id
JOIN sys.tables tParent  ON tParent.object_id = fk.referenced_object_id
JOIN sys.schemas schParent ON schParent.schema_id = tParent.schema_id
ORDER BY schChild.name, tChild.name, fk.name;
