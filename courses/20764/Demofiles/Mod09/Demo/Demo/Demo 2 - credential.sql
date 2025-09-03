-- Module 9 - Demo 2

-- Task 1
USE master;
GO

CREATE CREDENTIAL FileOperation 
WITH IDENTITY = N'ADVENTUREWORKS\FileOps', 
SECRET = N'Pa$$w0rd';
GO

-- Task 2
SELECT * FROM sys.credentials; 
GO
