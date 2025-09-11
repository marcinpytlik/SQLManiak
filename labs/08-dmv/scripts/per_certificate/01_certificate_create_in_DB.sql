/* ============================================================
   DMV wrappers — część bazodanowa (uruchom w docelowej bazie)
   Cel: procedury z DMV podpisane certyfikatem (bez VIEW SERVER STATE u userów)
   ============================================================ */

USE [AdventureWorks2022];
GO

/* [1] Parametry + przygotowanie (jeden batch) */
DECLARE @DbMasterKeyPwd  nvarchar(200) = N'ZmienToHaslo-DbMK!2025';
DECLARE @CertName        sysname       = N'dmv_cert';
DECLARE @CertSubject     nvarchar(200) = N'DMV wrappers signature';

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dba')
    EXEC('CREATE SCHEMA dba AUTHORIZATION dbo;');

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_dmv_cert_readers')
    CREATE ROLE [role_dmv_cert_readers] AUTHORIZATION [dbo];

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    DECLARE @sql_dmk nvarchar(max) =
        N'CREATE MASTER KEY ENCRYPTION BY PASSWORD = ' + QUOTENAME(@DbMasterKeyPwd,'''') + N';';
    EXEC(@sql_dmk);
END

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = @CertName)
BEGIN
    DECLARE @sql_cert nvarchar(max) =
        N'CREATE CERTIFICATE ' + QUOTENAME(@CertName) + N' WITH SUBJECT = ' + QUOTENAME(@CertSubject,'''') + N';';
    EXEC(@sql_cert);
END
GO

/* [2] Procedura – musi być pierwszą instrukcją w batchu */
CREATE OR ALTER PROC dba.usp_exec_requests
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
      r.session_id, r.status, r.command, r.wait_type, r.wait_time, r.blocking_session_id,
      r.cpu_time, r.total_elapsed_time, DB_NAME(r.database_id) AS dbname,
      SUBSTRING(t.text,(r.statement_start_offset/2)+1,
        ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text)
          ELSE r.statement_end_offset END - r.statement_start_offset)/2)+1) AS stmt_text
    FROM sys.dm_exec_requests AS r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
    WHERE r.session_id <> @@SPID;
END;
GO

/* [3] Podpis procedury (wykrywanie po major_id) */
IF EXISTS (
    SELECT 1
    FROM sys.crypt_properties
    WHERE class_desc = 'OBJECT_OR_COLUMN'
      AND major_id   = OBJECT_ID(N'dba.usp_exec_requests')
)
BEGIN
    DROP SIGNATURE FROM OBJECT::dba.usp_exec_requests BY CERTIFICATE dmv_cert;
END;
ADD  SIGNATURE TO   OBJECT::dba.usp_exec_requests BY CERTIFICATE dmv_cert;
GO

/* [4] Uprawnienia do wykonania wrappera */
GRANT EXECUTE ON dba.usp_exec_requests TO [role_dmv_cert_readers];
GO

/* [5] Eksport publicznego certyfikatu do pliku (.cer) */
/* [5] Eksport publicznego certyfikatu do pliku (.cer) — FILE musi być literałem */
DECLARE @CertFilePath nvarchar(400) = N'C:\TMP\dmv_cert.cer';  -- ścieżka zapisywalna dla konta usługi SQL

BEGIN TRY
    DECLARE @sql_backup nvarchar(max) =
        N'BACKUP CERTIFICATE dmv_cert TO FILE = ' + QUOTENAME(@CertFilePath, '''') + N';';
    EXEC(@sql_backup);

    PRINT N'Certyfikat wyeksportowany do: ' + @CertFilePath;
END TRY
BEGIN CATCH
    PRINT N'BACKUP CERTIFICATE nie powiódł się — sprawdź ścieżkę i prawa konta usługi SQL Server.';
    THROW;
END CATCH;
GO

/* [6] Weryfikacja w bazie */
SELECT 'DB' AS scope, DB_NAME() AS db_name, name AS cert_name, thumbprint
FROM sys.certificates WHERE name = N'dmv_cert';
GO
