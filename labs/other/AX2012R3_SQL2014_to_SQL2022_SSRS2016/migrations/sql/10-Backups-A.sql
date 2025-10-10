-- 10-Backups-A.sql
-- Wykonaj na serwerze A (SQL 2014). Zapis do udziału sieciowego.
:setvar BACKUP_DIR "\\A\Backup"

BACKUP DATABASE [DynamicsAX] TO DISK = '$(BACKUP_DIR)\DynamicsAX_FULL.bak' WITH INIT, COMPRESSION;
BACKUP DATABASE [DynamicsAX_model] TO DISK = '$(BACKUP_DIR)\DynamicsAX_MODEL_FULL.bak' WITH INIT, COMPRESSION;
BACKUP DATABASE [ReportServer] TO DISK = '$(BACKUP_DIR)\ReportServer_FULL.bak' WITH INIT, COMPRESSION;
BACKUP DATABASE [ReportServerTempDB] TO DISK = '$(BACKUP_DIR)\ReportServerTempDB_FULL.bak' WITH INIT, COMPRESSION;

-- (Opcjonalnie) logi, jeśli używasz FULL:
-- BACKUP LOG [DynamicsAX] TO DISK='$(BACKUP_DIR)\DynamicsAX_LOG.trn' WITH INIT, COMPRESSION;
