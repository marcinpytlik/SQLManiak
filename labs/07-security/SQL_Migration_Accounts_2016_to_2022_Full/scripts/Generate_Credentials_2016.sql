
/* Generate_Credentials_2016.sql */
SET NOCOUNT ON;
DECLARE @sql nvarchar(max);

SELECT @sql = STRING_AGG(CAST(
'IF NOT EXISTS (SELECT 1 FROM sys.credentials WHERE name = N' + QUOTENAME(c.name,'''') + ')
BEGIN
    PRINT N''Creating credential ' + REPLACE(c.name,'''','''''') + '''';
    CREATE CREDENTIAL ' + QUOTENAME(c.name) + '
        WITH IDENTITY = ' + QUOTENAME(c.credential_identity,'''') + ',
             SECRET = N''<<FILL_SECRET>>'';
END
ELSE
BEGIN
    PRINT N''Credential already exists: ' + REPLACE(c.name,'''','''''') + '''';
END
GO
' AS nvarchar(max)), CHAR(10))
FROM sys.credentials AS c;

SELECT @sql AS [-- Run on SQL 2022];
