/* Lab 06 — Diagnostyka: czemu nie trymuje? */
USE LogLab;

SELECT DB_NAME() AS dbname, log_truncation_holdup_reason
FROM sys.dm_db_log_stats(DB_ID());

SELECT name, recovery_model_desc, log_reuse_wait_desc
FROM sys.databases
WHERE name = 'LogLab';

/* Dodatkowe hamulce do sprawdzenia (własne scenariusze):
   - REPLICATION / CDC / CHANGE_TRACKING
   - AVAILABILITY_REPLICA (AG)
   - ACTIVE_BACKUP_OR_RESTORE
   - XTP_CHECKPOINT (In-Memory)
*/
