-- Stored procedures and definitions + MS_Description
SELECT 
    s.name AS schema_name,
    p.name AS proc_name,
    ep.value AS description,
    sm.definition
FROM sys.procedures p
JOIN sys.schemas s ON s.schema_id = p.schema_id
LEFT JOIN sys.sql_modules sm ON sm.object_id = p.object_id
LEFT JOIN sys.extended_properties ep 
    ON ep.major_id = p.object_id AND ep.minor_id = 0 AND ep.name = 'MS_Description'
ORDER BY s.name, p.name;
