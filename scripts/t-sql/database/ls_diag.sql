SELECT * FROM sys.servers WHERE is_linked = 1;
SELECT * FROM sys.linked_logins;
EXEC sp_helplinkedsrvlogin N'LS_SQLPROD';

SET ANSI_NULLS ON;
SET ANSI_WARNINGS ON;

SELECT TOP 5 * FROM OPENQUERY(LS_SQLPROD, 'SELECT @@version AS ver');