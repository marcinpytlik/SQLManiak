-- Tables + Columns + MS_Description (data dictionary core)
SELECT 
    s.name  AS schema_name,
    t.name  AS table_name,
    t.object_id,
    p.rows  AS approx_rowcount,
    ep_t.value AS table_description
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
LEFT JOIN sys.partitions AS p ON p.object_id = t.object_id AND p.index_id IN (0,1)
LEFT JOIN sys.extended_properties AS ep_t 
    ON ep_t.major_id = t.object_id AND ep_t.minor_id = 0 AND ep_t.name = 'MS_Description'
GROUP BY s.name, t.name, t.object_id, ep_t.value, t.create_date, t.modify_date, p.rows
ORDER BY s.name, t.name;

-- Columns with detail & description
SELECT 
    s.name  AS schema_name,
    t.name  AS table_name,
    c.column_id,
    c.name  AS column_name,
    ty.name AS data_type,
    c.max_length, c.precision, c.scale,
    c.is_nullable,
    dc.definition AS default_definition,
    ep_c.value AS column_description
FROM sys.tables t
JOIN sys.schemas s  ON s.schema_id = t.schema_id
JOIN sys.columns c  ON c.object_id = t.object_id
JOIN sys.types   ty ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints dc ON dc.parent_object_id = t.object_id AND dc.parent_column_id = c.column_id
LEFT JOIN sys.extended_properties ep_c 
    ON ep_c.major_id = c.object_id AND ep_c.minor_id = c.column_id AND ep_c.name = 'MS_Description'
ORDER BY s.name, t.name, c.column_id;
