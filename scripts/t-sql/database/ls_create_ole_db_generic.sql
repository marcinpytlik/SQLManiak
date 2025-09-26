EXEC sp_addlinkedserver
    @server     = N'LS_ORA',
    @srvproduct = N'Oracle',
    @provider   = N'OraOLEDB.Oracle',
    @datasrc    = N'ORCL';

EXEC sp_addlinkedsrvlogin
    @rmtsrvname = N'LS_ORA',
    @useself    = N'False',
    @locallogin = NULL,
    @rmtuser    = N'HR',
    @rmtpassword= N'S3cret!';

EXEC sp_serveroption N'LS_ORA', 'data access', 'true';
EXEC sp_serveroption N'LS_ORA', 'rpc out', 'true';
EXEC sp_serveroption N'LS_ORA', 'collation compatible', 'false';
EXEC sp_serveroption N'LS_ORA', 'use remote collation', 'true';