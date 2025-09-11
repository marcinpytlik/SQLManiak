/* cleanup_instance_all.sql — URUCHOM W master JAKO sysadmin
   Usuwa: uprawnienia VSS/VSP, członkostwa i role (role_dmv_server/srv_dmv_reader),
          login z certyfikatu + cert w master, testowe loginy (dmv_reader/new_reader).
*/

USE [master];
GO

/* --- USTAWIENIA --- */
DECLARE @DropLogins        bit = 1;  -- usuń loginy testowe (dmv_reader, new_reader)
DECLARE @DropServerRoles   bit = 1;  -- usuń role serwerowe (role_dmv_server, srv_dmv_reader)
DECLARE @DropCertLogin     bit = 1;  -- usuń login z certyfikatu (dmv_cert_login)
DECLARE @DropMasterCert    bit = 1;  -- usuń certyfikat dmv_cert w master

DECLARE @Principals TABLE(name sysname);
INSERT INTO @Principals(name) VALUES (N'dmv_reader'), (N'new_reader');

/* ZMIENNE POMOCNICZE (deklarowane raz na cały batch) */
DECLARE @sql     nvarchar(max);
DECLARE @p       sysname;
DECLARE @role    sysname;
DECLARE @member  sysname;

/* --- 1) REVOKE z PUBLIC (jeśli kiedyś dostał VSS/VSP) --- */
BEGIN TRY REVOKE VIEW SERVER STATE             TO [public]; END TRY BEGIN CATCH END CATCH;
BEGIN TRY REVOKE VIEW SERVER PERFORMANCE STATE TO [public]; END TRY BEGIN CATCH END CATCH;

/* --- 2) Odcinanie praw i członkostw dla loginów testowych --- */
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM @Principals;
OPEN cur; FETCH NEXT FROM cur INTO @p;
WHILE @@FETCH_STATUS = 0
BEGIN
  IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @p)
  BEGIN
    /* Revoke/Deny uprawnień serwerowych (bez błędów, jeśli brak) */
    SET @sql = N'REVOKE VIEW SERVER STATE TO ' + QUOTENAME(@p) + N';';              BEGIN TRY EXEC(@sql); END TRY BEGIN CATCH END CATCH;
    SET @sql = N'REVOKE VIEW SERVER PERFORMANCE STATE TO ' + QUOTENAME(@p) + N';';  BEGIN TRY EXEC(@sql); END TRY BEGIN CATCH END CATCH;
    SET @sql = N'REVOKE CONTROL SERVER TO ' + QUOTENAME(@p) + N';';                 BEGIN TRY EXEC(@sql); END TRY BEGIN CATCH END CATCH;

    SET @sql = N'DENY VIEW SERVER STATE TO ' + QUOTENAME(@p) + N';';                 BEGIN TRY EXEC(@sql); END TRY BEGIN CATCH END CATCH;
    SET @sql = N'DENY VIEW SERVER PERFORMANCE STATE TO ' + QUOTENAME(@p) + N';';     BEGIN TRY EXEC(@sql); END TRY BEGIN CATCH END CATCH;

    /* Usuń z ról serwerowych, jeśli był dodany (role_dmv_server/srv_dmv_reader/sysadmin) */
    IF EXISTS (
      SELECT 1
      FROM sys.server_role_members m
      JOIN sys.server_principals r ON r.principal_id = m.role_principal_id
      JOIN sys.server_principals p ON p.principal_id = m.member_principal_id
      WHERE p.name = @p AND r.name IN (N'role_dmv_server', N'srv_dmv_reader', N'sysadmin')
    )
    BEGIN
      DECLARE role_cur CURSOR LOCAL FAST_FORWARD FOR
      SELECT r.name
      FROM sys.server_role_members m
      JOIN sys.server_principals r ON r.principal_id = m.role_principal_id
      JOIN sys.server_principals p ON p.principal_id = m.member_principal_id
      WHERE p.name = @p AND r.name IN (N'role_dmv_server', N'srv_dmv_reader', N'sysadmin');

      OPEN role_cur; FETCH NEXT FROM role_cur INTO @role;
      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @sql = N'ALTER SERVER ROLE ' + QUOTENAME(@role) + N' DROP MEMBER ' + QUOTENAME(@p) + N';';
        BEGIN TRY EXEC(@sql); END TRY BEGIN CATCH END CATCH;
        FETCH NEXT FROM role_cur INTO @role;
      END
      CLOSE role_cur; DEALLOCATE role_cur;
    END
  END
  FETCH NEXT FROM cur INTO @p;
END
CLOSE cur; DEALLOCATE cur;

/* --- 3) Usuń login z certyfikatu (i jego GRANT-y) --- */
IF @DropCertLogin = 1 AND EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dmv_cert_login')
BEGIN
  BEGIN TRY REVOKE VIEW SERVER STATE             TO [dmv_cert_login]; END TRY BEGIN CATCH END CATCH;
  BEGIN TRY REVOKE VIEW SERVER PERFORMANCE STATE TO [dmv_cert_login]; END TRY BEGIN CATCH END CATCH;
  DROP LOGIN [dmv_cert_login];
END

/* --- 4) Usuń role serwerowe (po wyczyszczeniu członków) --- */
IF @DropServerRoles = 1
BEGIN
  DECLARE @RolesToDrop TABLE(role_name sysname);
  INSERT INTO @RolesToDrop(role_name) VALUES (N'role_dmv_server'), (N'srv_dmv_reader');

  DECLARE drop_cur CURSOR LOCAL FAST_FORWARD FOR SELECT role_name FROM @RolesToDrop;
  OPEN drop_cur; FETCH NEXT FROM drop_cur INTO @role;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @role)
    BEGIN
      -- zdejmij wszystkich członków
      WHILE EXISTS (
        SELECT 1
        FROM sys.server_role_members m
        JOIN sys.server_principals r ON r.principal_id = m.role_principal_id
        WHERE r.name = @role
      )
      BEGIN
        SELECT TOP 1 @member = p.name
        FROM sys.server_role_members m
        JOIN sys.server_principals r ON r.principal_id = m.role_principal_id
        JOIN sys.server_principals p ON p.principal_id = m.member_principal_id
        WHERE r.name = @role;

        SET @sql = N'ALTER SERVER ROLE ' + QUOTENAME(@role) + N' DROP MEMBER ' + QUOTENAME(@member) + N';';
        BEGIN TRY EXEC(@sql); END TRY BEGIN CATCH END CATCH;
      END

      -- drop samej roli
      SET @sql = N'DROP SERVER ROLE ' + QUOTENAME(@role) + N';';
      BEGIN TRY EXEC(@sql); END TRY BEGIN CATCH END CATCH;
    END
    FETCH NEXT FROM drop_cur INTO @role;
  END
  CLOSE drop_cur; DEALLOCATE drop_cur;
END

/* --- 5) Usuń certyfikat w master --- */
IF @DropMasterCert = 1 AND EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
BEGIN
  DROP CERTIFICATE [dmv_cert];
END

/* --- 6) Usuń loginy testowe --- */
IF @DropLogins = 1
BEGIN
  IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'new_reader')
    DROP LOGIN [new_reader];
  IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dmv_reader')
    DROP LOGIN [dmv_reader];
END

/* --- 7) Raport końcowy --- */
PRINT '--- RESZTKI (jeśli coś zostało) ---';
SELECT name, type_desc
FROM sys.server_principals
WHERE name IN (N'dmv_reader', N'new_reader', N'dmv_cert_login', N'role_dmv_server', N'srv_dmv_reader');

SELECT name AS cert_in_master
FROM sys.certificates
WHERE name = N'dmv_cert';

SELECT pr.name AS principal, sp.permission_name, sp.state_desc
FROM sys.server_permissions sp
JOIN sys.server_principals pr ON pr.principal_id = sp.grantee_principal_id
WHERE (pr.name IN (N'public', N'dmv_reader', N'new_reader', N'dmv_cert_login'))
  AND sp.class_desc = 'SERVER';
