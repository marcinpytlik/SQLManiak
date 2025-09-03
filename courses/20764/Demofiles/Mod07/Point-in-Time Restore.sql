--Create a database and back it up
CREATE DATABASE BackupDemo
GO
USE BackupDemo
GO
CREATE TABLE Customers
(CustomerID int identity primary key,
 FirstName nvarchar(50),
 LastName nvarchar(50))
 GO
BACKUP DATABASE [BackupDemo] TO  DISK = 'D:\Demofiles\Mod07\BackupDemo.bak'
WITH FORMAT, INIT,  NAME = 'BackupDemo Database Backup', COMPRESSION
GO

-- Enter some data
INSERT INTO BackupDemo.dbo.Customers
VALUES ('Dan', 'Drayton')
GO

-- Get the current time
SELECT getdate()

-- Enter some more data
INSERT INTO BackupDemo.dbo.Customers
VALUES ('Joan', 'Chambers')
GO

--Back up the transaction log
BACKUP LOG [BackupDemo] TO  DISK = 'D:\Demofiles\Mod07\BackupDemo.bak'
WITH NOFORMAT, NOINIT,  NAME = 'BackupDemo Log Backup', COMPRESSION
GO

