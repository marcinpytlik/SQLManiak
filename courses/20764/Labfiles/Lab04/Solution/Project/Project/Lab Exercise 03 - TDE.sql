-- Module 4 Exercise 3

-- Task 1 - create a master key
USE master;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'CRVmNe4jTDMIfYiFnMNp$';
GO

-- Task 2 - backup the server master key
-- edit the following query to back up the server master key to
-- D:\Labfiles\Lab04\Starter\Audit\smk.bak
-- Encrypt the backup with the password iD2Z1i85saFyAiK7auzn$
BACKUP MASTER KEY TO FILE = 'D:\Labfiles\Lab04\Starter\Audit\smk.bak' 
    ENCRYPTION BY PASSWORD = 'iD2Z1i85saFyAiK7auzn$';

-- Task 3 - create a server certificate
CREATE CERTIFICATE TDE_cert WITH SUBJECT = 'exercise TDE certificate';
GO

-- Task 4 - back up the server certificate
-- edit the following query to back up the TDE_cert certificate to D:\Labfiles\Lab04\Starter\Audit\TDE_cert.bak
-- and to back up the TDE_cert private key to D:\Labfiles\Lab04\Starter\Audit\TDE_cert_pk.bak,
-- using the password *R8vkULA5aKhp3ekGg1o3
BACKUP CERTIFICATE TDE_cert 
TO FILE = 'D:\Labfiles\Lab04\Starter\Audit\TDE_cert.bak'
WITH PRIVATE KEY 
(
    FILE = 'D:\Labfiles\Lab04\Starter\Audit\TDE_cert_pk.bak',
    ENCRYPTION BY PASSWORD = '*R8vkULA5aKhp3ekGg1o3'
);
GO

-- Task 5 - create a database encryption key in salesapp1
-- Edit the following query to create a database encryption key using the AES_256 algorithm
-- and encrypted by the server certificate TDE_cert
USE salesapp1;
GO
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE TDE_cert;
GO

-- Task 6 - enable encryption for salesapp1
ALTER DATABASE salesapp1
SET ENCRYPTION ON;
GO

-- Task 7 - examine the sys.dm_database_encryption_keys DMV
-- notice that both salesapp1 and tempdb have been encrypted
-- (tempdb is encrypted if any database on the instance is encrypted)
SELECT d.name, d.is_encrypted, ek.*
FROM sys.dm_database_encryption_keys AS ek
JOIN sys.databases AS d
ON d.database_id = ek.database_id;
GO
