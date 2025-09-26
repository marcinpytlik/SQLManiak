EXEC sp_addlinkedserver
    @server     = N'LS_SQLPROD',
    @srvproduct = N'SQL Server',
    @provider   = N'MSOLEDBSQL',
    @datasrc    = N'SQLPROD\INST1';

EXEC sp_addlinkedsrvlogin
    @rmtsrvname = N'LS_SQLPROD',
    @useself    = N'False',
    @locallogin = NULL,
    @rmtuser    = N'app_reader',
    @rmtpassword= N'S3cret!';

EXEC sp_serveroption N'LS_SQLPROD', 'data access', 'true';
EXEC sp_serveroption N'LS_SQLPROD', 'rpc', 'true';
EXEC sp_serveroption N'LS_SQLPROD', 'rpc out', 'true';

SELECT TOP 10 * FROM LS_SQLPROD.master.sys.databases;
SELECT TOP 10 * FROM OPENQUERY(LS_SQLPROD, 'SELECT name, create_date FROM sys.databases');