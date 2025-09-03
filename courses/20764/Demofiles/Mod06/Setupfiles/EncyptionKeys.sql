--Create a database master key 
USE master
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Sqlserver2016@';
SELECT * FROM sys.symmetric_keys;
--End create a database master key

--Backup the database master key
OPEN MASTER KEY DECRYPTION BY PASSWORD = 'Sqlserver2016@';
BACKUP MASTER KEY TO FILE = 'D:\Backups\master.key'
ENCRYPTION BY PASSWORD = 'Sqlserver2016@';
GO
--End backup the database master key

--Create a certificate
CREATE CERTIFICATE AdventureWorksCert
WITH SUBJECT = 'AdventureWorks Certificate';
--End create a certificate

--Backup the certificate and its private key
BACKUP CERTIFICATE AdventureWorksCert 
TO FILE = 'D:\Backups\AdventureWorksCert.cer'
WITH PRIVATE KEY ( file = 'D:\Backups\AdventureWorksCert.pvk' ,
encryption by password = 'Sqlserver2016@');
GO
--End backup the certificate and its private key



