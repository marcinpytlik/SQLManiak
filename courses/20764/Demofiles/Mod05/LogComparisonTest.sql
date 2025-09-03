-- Perform a full database backup
USE [LogTest]
GO

BACKUP DATABASE LogTest
TO DISK = 'D:\Demofiles\Mod05\LogTest.bak'
   WITH FORMAT,
      MEDIANAME = 'LogTest',
      NAME = 'Full Backup of LogTest';
GO
-- End of perform a full database backup

-- View log file space
DBCC SQLPERF(logspace) 
-- End of view log file space

-- Insert data
DECLARE @num INT;
SET @num=1;
WHILE @num < 10000
BEGIN 
    INSERT tLogTest(col1) 
    VALUES(@num); 
    SET @num = @num + 1;
END
-- End insert data

-- View log file space
DBCC SQLPERF(logspace) 
-- End of view log file space

-- Issue checkpoint
CHECKPOINT
-- End issue checkpoint

-- View log file space
DBCC SQLPERF(logspace) 
-- End of view log file space

-- Check log status
SELECT name, recovery_model_desc, log_reuse_wait_desc from sys.databases
WHERE name = 'LogTest'
-- End check log status

-- Perform a log backup
USE [LogTest]
GO

BACKUP LOG LogTest
TO DISK = 'D:\Demofiles\Mod05\LogTest.trn'
   WITH FORMAT, DESCRIPTION = 'LogTest log backup';
GO
-- End perform a log backup

-- Verify log file truncation
DBCC SQLPERF(logspace) -- note the reduced Log Space Used (%)
-- End of verify log file truncation