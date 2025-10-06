USE tempdb;
GO
SELECT request_session_id AS spid,
       resource_type,
       resource_subtype,
       resource_description,
       request_mode,
       request_status
FROM sys.dm_tran_locks
WHERE resource_associated_entity_id = OBJECT_ID('dbo.DemoLocks')
ORDER BY spid, resource_type;
