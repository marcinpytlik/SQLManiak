USE [master]
RESTORE DATABASE [HumanResources] FROM  DISK = N'D:\Labfiles\Lab07\Backups\HumanResources.bak' WITH  FILE = 2,  NOUNLOAD,  STATS = 5

GO


