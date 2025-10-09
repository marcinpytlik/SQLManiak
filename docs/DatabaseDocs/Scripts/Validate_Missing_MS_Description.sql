-- Validate missing MS_Description on tables/columns/views/procs
-- Missing table descriptions
SELECT s.name AS schema_name, t.name AS table_name, 'TABLE' AS object_type
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = t.object_id AND ep.minor_id = 0 AND ep.name = 'MS_Description'
WHERE ep.value IS NULL;

-- Missing column descriptions
SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name, 'COLUMN' AS object_type
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id AND ep.name = 'MS_Description'
WHERE ep.value IS NULL;

-- Missing view descriptions
SELECT s.name AS schema_name, v.name AS view_name, 'VIEW' AS object_type
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = v.object_id AND ep.minor_id = 0 AND ep.name = 'MS_Description'
WHERE ep.value IS NULL;

-- Missing procedure descriptions
SELECT s.name AS schema_name, p.name AS proc_name, 'PROC' AS object_type
FROM sys.procedures p
JOIN sys.schemas s ON s.schema_id = p.schema_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = p.object_id AND ep.minor_id = 0 AND ep.name = 'MS_Description'
WHERE ep.value IS NULL;
