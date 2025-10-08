/* sql/00_discover_audits.sql
   Podgląd dostępnych audytów i ścieżek plików
*/

-- Lista uruchomionych audytów i ich ścieżek (aktywny writer)
SELECT 
    s.audit_id, s.audit_name, s.status_desc, s.event_time, s.file_path
FROM sys.dm_server_audit_status AS s
ORDER BY s.audit_name, s.event_time DESC;

-- Ścieżki zdefiniowane w audytach plikowych (niezależnie od statusu)
SELECT 
    a.name AS audit_name,
    fa.file_path,
    a.is_state_enabled
FROM sys.server_audits AS a
LEFT JOIN sys.server_file_audits AS fa
    ON fa.audit_id = a.audit_id
ORDER BY a.name;
