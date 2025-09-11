/* ============================================================
   DMV wrappers — instancja (uruchom w master)
   Login z certyfikatu + GRANT VIEW SERVER STATE
   ============================================================ */
USE [master];
GO

DECLARE @CertName       sysname       = N'dmv_cert';
DECLARE @CertFilePath   nvarchar(400) = N'C:\TMP\dmv_cert.cer';  -- ten sam plik co w A
DECLARE @LoginFromCert  sysname       = N'dmv_cert_login';
DECLARE @sql            nvarchar(max);

/* 1) Import certyfikatu publicznego do master (jeśli brak) */
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = @CertName)
BEGIN
    SET @sql = N'CREATE CERTIFICATE ' + QUOTENAME(@CertName)
             + N' FROM FILE = ' + QUOTENAME(@CertFilePath, '''') + N';';
    EXEC sys.sp_executesql @sql;
END

/* 2) Login z certyfikatu (jeśli brak) */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @LoginFromCert)
BEGIN
    SET @sql = N'CREATE LOGIN ' + QUOTENAME(@LoginFromCert)
             + N' FROM CERTIFICATE ' + QUOTENAME(@CertName) + N';';
    EXEC sys.sp_executesql @sql;
END

/* 3) Uprawnienie instancji (VIEW SERVER STATE) dla loginu certyfikatowego */
IF NOT EXISTS (
    SELECT 1
    FROM sys.server_permissions p
    JOIN sys.server_principals  s ON s.principal_id = p.grantee_principal_id
    WHERE s.name = @LoginFromCert
      AND p.permission_name = N'VIEW SERVER STATE'
)
BEGIN
    SET @sql = N'GRANT VIEW SERVER STATE TO ' + QUOTENAME(@LoginFromCert) + N';';
    EXEC sys.sp_executesql @sql;
END

/* 4) Weryfikacja */
SELECT 'MASTER' AS scope, name AS cert_name, thumbprint
FROM sys.certificates WHERE name = @CertName;

SELECT 'LOGIN'  AS scope, name AS login_name, type_desc, is_disabled
FROM sys.server_principals WHERE name = @LoginFromCert;

SELECT 'PERM'   AS scope, p.permission_name, p.state_desc
FROM sys.server_permissions p
JOIN sys.server_principals s ON s.principal_id = p.grantee_principal_id
WHERE s.name = @LoginFromCert;
