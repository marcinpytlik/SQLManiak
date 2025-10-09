/*
  Porównanie SID-ów loginów agentów replikacji między A i C.
  Wariant 1: jeżeli masz skonfigurowany Linked Server do C na A (np. [ServerC]).
  Wariant 2: uruchom skrypt osobno na A i C i porównaj wyniki (kolumny spójne).
*/

-- ===================== PARAMETRY =====================
DECLARE @LinkedToC sysname = N'ServerC'; -- nazwij jak Twój Linked Server do C; jeśli brak, pozostaw jak jest
-- Lista loginów do weryfikacji (rozszerz wg potrzeb)
DECLARE @Logins TABLE(name sysname);
INSERT INTO @Logins(name)
VALUES (N'repl_distribution'),(N'repl_logreader'),(N'repl_snapshot');  -- dodaj konta agentów, konta domenowe, itp.
-- =====================================================

-- WYNIK PO STRONIE LOKALNEJ INSTANCJI
;WITH L AS (
  SELECT sp.name, sp.sid, sp.type_desc,
         TRY_CONVERT(bit, CASE WHEN sl.is_disabled = 1 THEN 1 ELSE 0 END) AS is_disabled,
         sl.default_database_name AS default_db
  FROM sys.server_principals sp
  LEFT JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
  WHERE sp.name IN (SELECT name FROM @Logins)
)
SELECT 'LOCAL' AS src, * FROM L;

-- JEŚLI ISTNIEJE LINKED SERVER DO C, POKAŻ ZESTAWIENIE RÓWNOLEGŁE
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = @LinkedToC)
BEGIN
    DECLARE @sql nvarchar(max) = N'
    ;WITH R AS (
      SELECT sp.name, sp.sid, sp.type_desc,
             TRY_CONVERT(bit, CASE WHEN sl.is_disabled = 1 THEN 1 ELSE 0 END) AS is_disabled,
             sl.default_database_name AS default_db
      FROM sys.server_principals sp
      LEFT JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
      WHERE sp.name IN (SELECT name FROM (VALUES ' + STRING_AGG('(''' + STRING_ESCAPE(LTRIM(RTRIM(name)), ''')') + ''')', ',' ) WITHIN GROUP (ORDER BY name) + N') v(name))
    )
    SELECT ''REMOTE(C)'' AS src, * FROM R;
    ';
    EXEC (@sql) AT [ServerC];
END
ELSE
BEGIN
    PRINT 'Brak linked server do C. Uruchom ten skrypt również na C i porównaj wyniki.';
END;

-- Porównanie (gdy jest Linked Server)
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = @LinkedToC)
BEGIN
    ;WITH A AS (
      SELECT sp.name, sp.sid
      FROM sys.server_principals sp
      WHERE sp.name IN (SELECT name FROM @Logins)
    ),
    C AS (
      SELECT sp.name, sp.sid
      FROM OPENQUERY([ServerC], '
        SELECT name, sid
        FROM sys.server_principals
      ') AS sp
      WHERE sp.name IN (SELECT name FROM @Logins)
    )
    SELECT COALESCE(A.name, C.name) AS login_name,
           A.sid AS sid_A,
           C.sid AS sid_C,
           CASE WHEN A.sid = C.sid THEN 1 ELSE 0 END AS sid_match
    FROM A
    FULL OUTER JOIN C ON A.name = C.name
    ORDER BY login_name;
END
