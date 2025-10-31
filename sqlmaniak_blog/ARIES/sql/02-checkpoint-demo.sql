
-- 02-checkpoint-demo.sql
USE ARIES_Demo;
GO

CHECKPOINT;
PRINT 'Checkpoint executed.';

DBCC SQLPERF(LOGSPACE);
SELECT * FROM sys.dm_db_log_space_usage;
