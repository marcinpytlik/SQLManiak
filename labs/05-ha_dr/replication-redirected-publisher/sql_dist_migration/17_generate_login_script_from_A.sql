/*
  GENERATOR skryptu loginów (do uruchomienia na A), aby przenieść SQL loginy na C
  z zachowaniem SID i hasła (hash). Dla Windows loginów – utwórz w AD, nie skryptujemy hasła.

  Wynik: zestaw CREATE LOGIN do wykonania na C.
*/

SET NOCOUNT ON;

DECLARE @IncludeRoles bit = 1; -- jeżeli chcesz dodać nadania ról serwerowych

;WITH src AS (
  SELECT sp.name, sp.type_desc,
         sl.password_hash, sp.sid,
         sl.is_disabled, sl.default_database_name,
         sl.default_language_name
  FROM sys.server_principals sp
  LEFT JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
  WHERE sp.type IN ('S','U') -- SQL LOGIN = 'S', WINDOWS LOGIN = 'U'
    AND sp.name NOT LIKE '##%'
    AND sp.name NOT IN ('sa') -- pominąć jeśli nie chcesz dotykać sa
    AND sp.name IN (N'repl_distribution', N'repl_logreader', N'repl_snapshot') -- DOPASUJ LISTĘ
)
SELECT 
  CASE 
    WHEN type_desc = 'SQL_LOGIN' THEN
      '/* SQL LOGIN */' + CHAR(13) + CHAR(10) +
      'IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N''' + name + ''')' + CHAR(13) + CHAR(10) +
      'CREATE LOGIN [' + name + '] ' +
      'WITH PASSWORD = ' + CONVERT(varchar(max), password_hash, 1) + ' HASHED, ' +
      'SID = ' + CONVERT(varchar(max), sid, 1) + ', ' +
      'CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF, ' +
      'DEFAULT_DATABASE = [' + ISNULL(default_database_name,'master') + '], ' +
      'DEFAULT_LANGUAGE = [' + ISNULL(default_language_name,'us_english') + '];'
    WHEN type_desc = 'WINDOWS_LOGIN' THEN
      '/* WINDOWS LOGIN */' + CHAR(13) + CHAR(10) +
      '-- Upewnij się, że konto istnieje w AD i ma dostęp.' + CHAR(13) + CHAR(10) +
      'IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N''' + name + ''')' + CHAR(13) + CHAR(10) +
      'CREATE LOGIN [' + name + '] FROM WINDOWS WITH DEFAULT_DATABASE=[' + ISNULL(default_database_name,'master') + '];'
  END
  + CHAR(13) + CHAR(10) +
  CASE WHEN is_disabled = 1 THEN 'ALTER LOGIN [' + name + '] DISABLE;' + CHAR(13) + CHAR(10) ELSE '' END
AS [-- ScriptToRunOn_C]
FROM src
ORDER BY type_desc, name;

IF @IncludeRoles = 1
BEGIN
  PRINT '/* Nadania ról serwerowych – uruchom na C po utworzeniu loginów */';
  SELECT 'EXEC sp_addsrvrolemember @loginame = N''' + sp.name + ''', @rolename = N''' + r.name + ''';'
  FROM sys.server_role_members srm
  JOIN sys.server_principals r  ON r.principal_id  = srm.role_principal_id
  JOIN sys.server_principals sp ON sp.principal_id = srm.member_principal_id
  WHERE sp.name IN (N'repl_distribution', N'repl_logreader', N'repl_snapshot')  -- DOPASUJ
  ORDER BY sp.name, r.name;
END
