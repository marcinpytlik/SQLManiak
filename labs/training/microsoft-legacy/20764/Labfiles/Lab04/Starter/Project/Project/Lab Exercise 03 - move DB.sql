-- Module 4 Exercise 3 - move database

-- Task 10 - create server master key
USE master;
GO
IF @@SERVERNAME = 'MIA-SQL\SQL2'
BEGIN
	CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'CRVmNe4jTDMIfYiFnMNp*';
END
ELSE
	THROW 50001,'Connect this query window to the MIA-SQL\SQL2 instance',1;
GO

-- Task 11 - create server certificate from backup
CREATE CERTIFICATE TDE_cert 
FROM FILE = 'D:\Labfiles\Lab04\Starter\Audit\TDE_cert.bak'
WITH PRIVATE KEY 
(
    FILE = 'D:\Labfiles\Lab04\Starter\Audit\TDE_cert_pk.bak',
    DECRYPTION BY PASSWORD = '*R8vkULA5aKhp3ekGg1o3'
);
GO

-- Task 12 - verify access to the database
SELECT TOP 10 * from salesapp1.Sales.Customers;
