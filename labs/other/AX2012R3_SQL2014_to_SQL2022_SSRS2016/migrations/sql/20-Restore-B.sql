-- 20-Restore-B.sql
-- Uruchom na serwerze B (SQL 2022). Dopasuj ścieżki.
:setvar BACKUP_DIR "\\A\Backup"
:setvar DATA_DIR "D:\SQLData"
:setvar LOG_DIR "E:\SQLLogs"

RESTORE DATABASE [DynamicsAX]
FROM DISK = '$(BACKUP_DIR)\DynamicsAX_FULL.bak'
WITH MOVE 'DynamicsAX_Data' TO '$(DATA_DIR)\DynamicsAX.mdf',
     MOVE 'DynamicsAX_Log'  TO '$(LOG_DIR)\DynamicsAX.ldf',
     RECOVERY, REPLACE;

RESTORE DATABASE [DynamicsAX_model]
FROM DISK = '$(BACKUP_DIR)\DynamicsAX_MODEL_FULL.bak'
WITH MOVE 'DynamicsAX_model' TO '$(DATA_DIR)\DynamicsAX_model.mdf',
     MOVE 'DynamicsAX_model_log' TO '$(LOG_DIR)\DynamicsAX_model.ldf',
     RECOVERY, REPLACE;

-- (Opcjonalnie) jeżeli przenosisz katalog SSRS na B:
-- RESTORE DATABASE [ReportServer] FROM DISK='$(BACKUP_DIR)\ReportServer_FULL.bak' WITH MOVE ..., REPLACE;
-- RESTORE DATABASE [ReportServerTempDB] FROM DISK='$(BACKUP_DIR)\ReportServerTempDB_FULL.bak' WITH MOVE ..., REPLACE;
