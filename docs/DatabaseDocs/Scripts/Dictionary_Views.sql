-- Views and definitions + MS_Description
SELECT 
    s.name AS schema_name,
    v.name AS view_name,
    ep.value AS description,
    sm.definition
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
LEFT JOIN sys.sql_modules sm ON sm.object_id = v.object_id
LEFT JOIN sys.extended_properties ep 
    ON ep.major_id = v.object_id AND ep.minor_id = 0 AND ep.name = 'MS_Description'
ORDER BY s.name, v.name;
