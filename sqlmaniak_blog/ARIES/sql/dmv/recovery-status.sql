
-- dmv/recovery-status.sql
SELECT database_id, last_checkpoint_lsn, recovery_model_desc, log_reuse_wait_desc
FROM sys.database_recovery_status AS rs
JOIN sys.databases AS d ON rs.database_id = d.database_id
WHERE d.name = 'ARIES_Demo';
