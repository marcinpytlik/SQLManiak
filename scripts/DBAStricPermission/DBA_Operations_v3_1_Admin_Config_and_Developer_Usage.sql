/*
===============================================================================
DBA_Operations v3
ADMIN CONFIGURATION + DEVELOPER USAGE
===============================================================================

ZAŁOŻENIA:
  - DBA_Operations v3 FULL Deployment jest już wdrożone.
  - Grupa AD: SQLLAB\Developer
  - Przykładowa baza: baza

TEN PLIK MA DWIE SEKCJE:
  A. ADMINISTRATOR - konfiguracja grupy i baz
  B. DEVELOPER     - przykłady operacji
===============================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   A1. ADMINISTRATOR - LOGIN GRUPY AD
   ============================================================================ */
USE [master];
GO

IF SUSER_ID(N'SQLLAB\Developer') IS NULL
BEGIN
    CREATE LOGIN [SQLLAB\Developer]
    FROM WINDOWS;
END;
GO

/* ============================================================================
   A2. ADMINISTRATOR - USER GRUPY W DBA_Operations
   ============================================================================ */
USE [DBA_Operations];
GO

IF DATABASE_PRINCIPAL_ID(N'SQLLAB\Developer') IS NULL
BEGIN
    CREATE USER [SQLLAB\Developer]
    FOR LOGIN [SQLLAB\Developer];
END;
GO

/*
Domyślny model:
  - DDL: TAK
  - Database Security: TAK
  - Backup: NIE (włącz osobno, jeśli naprawdę potrzebny)
*/
IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
    WHERE r.name=N'DBA_DeveloperDdlOperator'
      AND m.name=N'SQLLAB\Developer'
)
    ALTER ROLE [DBA_DeveloperDdlOperator] ADD MEMBER [SQLLAB\Developer];
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
    WHERE r.name=N'DBA_DeveloperSecurityOperator'
      AND m.name=N'SQLLAB\Developer'
)
    ALTER ROLE [DBA_DeveloperSecurityOperator] ADD MEMBER [SQLLAB\Developer];
GO

/*
OPCJONALNIE:
ALTER ROLE [DBA_DeveloperBackupOperator]
ADD MEMBER [SQLLAB\Developer];
*/

/* ============================================================================
   A3. ADMINISTRATOR - DODANIE BAZY DO MANAGED DATABASES
   ============================================================================ */
MERGE dbo.ManagedDatabase AS T
USING
(
    SELECT
        N'baza' AS DatabaseName,
        CONVERT(bit,1) AS AllowDdl,
        CONVERT(bit,1) AS AllowSecurity,
        CONVERT(bit,0) AS AllowBackup,
        CONVERT(bit,1) AS IsEnabled,
        N'Baza developerska zarządzana przez DBA_Operations v3' AS Comment
) AS S
ON T.DatabaseName=S.DatabaseName
WHEN MATCHED THEN
    UPDATE SET
        AllowDdl=S.AllowDdl,
        AllowSecurity=S.AllowSecurity,
        AllowBackup=S.AllowBackup,
        IsEnabled=S.IsEnabled,
        Comment=S.Comment
WHEN NOT MATCHED THEN
    INSERT(DatabaseName,AllowDdl,AllowSecurity,AllowBackup,IsEnabled,Comment)
    VALUES(S.DatabaseName,S.AllowDdl,S.AllowSecurity,S.AllowBackup,S.IsEnabled,S.Comment);
GO

/* ============================================================================
   A4. ADMINISTRATOR - NORMALNY DOSTĘP GRUPY DO BAZY
   ============================================================================ */
USE [baza];
GO

IF DATABASE_PRINCIPAL_ID(N'SQLLAB\Developer') IS NULL
BEGIN
    CREATE USER [SQLLAB\Developer]
    FOR LOGIN [SQLLAB\Developer];
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
    WHERE r.name=N'db_datareader'
      AND m.name=N'SQLLAB\Developer'
)
    ALTER ROLE [db_datareader] ADD MEMBER [SQLLAB\Developer];
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
    WHERE r.name=N'db_datawriter'
      AND m.name=N'SQLLAB\Developer'
)
    ALTER ROLE [db_datawriter] ADD MEMBER [SQLLAB\Developer];
GO

/*
    Własna rola wykonawcza.
    EXECUTE ON SCHEMA::dbo obejmuje istniejące i przyszłe procedury/funkcje
    wykonywalne w schemacie dbo.
*/
IF DATABASE_PRINCIPAL_ID(N'db_executor') IS NULL
BEGIN
    CREATE ROLE [db_executor] AUTHORIZATION [dbo];
END;
GO

GRANT EXECUTE
ON SCHEMA::[dbo]
TO [db_executor];
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
    WHERE r.name=N'db_executor'
      AND m.name=N'SQLLAB\Developer'
)
BEGIN
    ALTER ROLE [db_executor]
    ADD MEMBER [SQLLAB\Developer];
END;
GO

/*
WAŻNE:
NIE DODAJEMY:
    db_owner
    db_ddladmin
    db_securityadmin
    db_accessadmin
*/

/* ============================================================================
   A5. ADMINISTRATOR - CERTYFIKAT DDL W BAZIE [baza]
   Publiczny certyfikat = brak klucza prywatnego w bazie aplikacyjnej.
   ============================================================================ */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.certificates
    WHERE name=N'DBAOps_DdlCert'
)
BEGIN
    CREATE CERTIFICATE [DBAOps_DdlCert]
    FROM FILE='C:\Temp\DBAOps_DdlCert.cer';
END;
GO

IF DATABASE_PRINCIPAL_ID(N'DBAOps_DdlCertUser') IS NULL
BEGIN
    CREATE USER [DBAOps_DdlCertUser]
    FROM CERTIFICATE [DBAOps_DdlCert];
END;
GO

/*
Minimalne prawa potrzebne wrapperom DDL w schemacie dbo.
ALTER ON SCHEMA::dbo pozwala modyfikować obiekty w dbo.
CREATE xxx jest wymagane do tworzenia danego typu obiektu.
*/
GRANT ALTER ON SCHEMA::[dbo] TO [DBAOps_DdlCertUser];
GRANT CREATE TABLE     TO [DBAOps_DdlCertUser];
GRANT CREATE VIEW      TO [DBAOps_DdlCertUser];
GRANT CREATE PROCEDURE TO [DBAOps_DdlCertUser];
GO

/* ============================================================================
   A6. ADMINISTRATOR - CERTYFIKAT DATABASE SECURITY W BAZIE [baza]
   ============================================================================ */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.certificates
    WHERE name=N'DBAOps_SecurityCert'
)
BEGIN
    CREATE CERTIFICATE [DBAOps_SecurityCert]
    FROM FILE='C:\Temp\DBAOps_SecurityCert.cer';
END;
GO

IF DATABASE_PRINCIPAL_ID(N'DBAOps_SecurityCertUser') IS NULL
BEGIN
    CREATE USER [DBAOps_SecurityCertUser]
    FROM CERTIFICATE [DBAOps_SecurityCert];
END;
GO

GRANT ALTER ANY USER TO [DBAOps_SecurityCertUser];

/*
Tylko role dozwolone przez rozwiązanie.
Nie nadajemy ALTER ANY ROLE ani db_securityadmin.
*/
GRANT ALTER ON ROLE::[db_datareader] TO [DBAOps_SecurityCertUser];
GRANT ALTER ON ROLE::[db_datawriter] TO [DBAOps_SecurityCertUser];
GO

/* ============================================================================
   A7. ADMINISTRATOR - CERTYFIKAT BACKUP (OPCJONALNIE)
   Wykonaj tylko gdy ManagedDatabase.AllowBackup = 1 i grupa ma rolę backup.
   ============================================================================ */
/*
IF NOT EXISTS
(
    SELECT 1
    FROM sys.certificates
    WHERE name=N'DBAOps_BackupCert'
)
BEGIN
    CREATE CERTIFICATE [DBAOps_BackupCert]
    FROM FILE='C:\Temp\DBAOps_BackupCert.cer';
END;
GO

IF DATABASE_PRINCIPAL_ID(N'DBAOps_BackupCertUser') IS NULL
BEGIN
    CREATE USER [DBAOps_BackupCertUser]
    FROM CERTIFICATE [DBAOps_BackupCert];
END;
GO

ALTER ROLE [db_backupoperator]
ADD MEMBER [DBAOps_BackupCertUser];
GO
*/

/* ============================================================================
   A8. ADMINISTRATOR - WERYFIKACJA, ŻE GRUPA NIE MA db_owner
   ============================================================================ */
SELECT
    r.name AS DatabaseRole,
    m.name AS MemberName
FROM sys.database_role_members drm
JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
WHERE m.name=N'SQLLAB\Developer'
ORDER BY r.name;
GO

/*
Oczekiwane:
    db_datareader
    db_datawriter
    db_executor

NIE powinno być:
    db_owner
    db_ddladmin
    db_securityadmin
*/

/* ============================================================================
   A9. ADMINISTRATOR - WERYFIKACJA KONFIGURACJI CENTRALNEJ
   ============================================================================ */
USE [DBA_Operations];
GO

SELECT *
FROM dbo.ManagedDatabase
ORDER BY DatabaseName;

SELECT
    r.name AS DBAOperationsRole,
    m.name AS MemberName
FROM sys.database_role_members drm
JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
WHERE m.name=N'SQLLAB\Developer'
ORDER BY r.name;
GO

/* ============================================================================
   A10. ADMINISTRATOR - DODANIE KOLEJNEJ BAZY

   Poniższy blok jest kompletnym przykładem onboardingu kolejnej bazy.
   Zmień nazwę [baza2] oraz przełączniki Allow*.

   Kroki:
     1. ManagedDatabase
     2. SQLLAB\Developer -> USER
     3. db_datareader
     4. db_datawriter
     5. db_executor + EXECUTE ON SCHEMA::dbo
     6. certyfikat DDL + minimalne prawa
     7. opcjonalnie certyfikat Security
     8. opcjonalnie certyfikat Backup
   ============================================================================ */

/* A10.1 - wpis centralny */
USE [DBA_Operations];
GO

MERGE dbo.ManagedDatabase AS T
USING
(
    SELECT
        N'baza2' AS DatabaseName,
        CONVERT(bit,1) AS AllowDdl,
        CONVERT(bit,1) AS AllowSecurity,
        CONVERT(bit,0) AS AllowBackup,
        CONVERT(bit,1) AS IsEnabled,
        N'Onboarding przez DBA_Operations v3.1' AS Comment
) AS S
ON T.DatabaseName=S.DatabaseName
WHEN MATCHED THEN
    UPDATE SET
        AllowDdl=S.AllowDdl,
        AllowSecurity=S.AllowSecurity,
        AllowBackup=S.AllowBackup,
        IsEnabled=S.IsEnabled,
        Comment=S.Comment
WHEN NOT MATCHED THEN
    INSERT(DatabaseName,AllowDdl,AllowSecurity,AllowBackup,IsEnabled,Comment)
    VALUES(S.DatabaseName,S.AllowDdl,S.AllowSecurity,S.AllowBackup,S.IsEnabled,S.Comment);
GO

/* A10.2 - grupa developerska w bazie */
USE [baza2];
GO

IF DATABASE_PRINCIPAL_ID(N'SQLLAB\Developer') IS NULL
BEGIN
    CREATE USER [SQLLAB\Developer]
    FOR LOGIN [SQLLAB\Developer];
END;
GO

/* A10.3 - prawa do danych */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
    WHERE r.name=N'db_datareader'
      AND m.name=N'SQLLAB\Developer'
)
    ALTER ROLE [db_datareader] ADD MEMBER [SQLLAB\Developer];
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
    WHERE r.name=N'db_datawriter'
      AND m.name=N'SQLLAB\Developer'
)
    ALTER ROLE [db_datawriter] ADD MEMBER [SQLLAB\Developer];
GO

/* A10.4 - rola db_executor */
IF DATABASE_PRINCIPAL_ID(N'db_executor') IS NULL
BEGIN
    CREATE ROLE [db_executor] AUTHORIZATION [dbo];
END;
GO

GRANT EXECUTE
ON SCHEMA::[dbo]
TO [db_executor];
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
    WHERE r.name=N'db_executor'
      AND m.name=N'SQLLAB\Developer'
)
BEGIN
    ALTER ROLE [db_executor]
    ADD MEMBER [SQLLAB\Developer];
END;
GO

/* A10.5 - certyfikat DDL */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.certificates
    WHERE name=N'DBAOps_DdlCert'
)
BEGIN
    CREATE CERTIFICATE [DBAOps_DdlCert]
    FROM FILE='C:\Temp\DBAOps_DdlCert.cer';
END;
GO

IF DATABASE_PRINCIPAL_ID(N'DBAOps_DdlCertUser') IS NULL
BEGIN
    CREATE USER [DBAOps_DdlCertUser]
    FROM CERTIFICATE [DBAOps_DdlCert];
END;
GO

GRANT ALTER ON SCHEMA::[dbo] TO [DBAOps_DdlCertUser];
GRANT CREATE TABLE           TO [DBAOps_DdlCertUser];
GRANT CREATE VIEW            TO [DBAOps_DdlCertUser];
GRANT CREATE PROCEDURE       TO [DBAOps_DdlCertUser];
GO

/* A10.6 - certyfikat Security; wykonaj tylko jeśli AllowSecurity=1 */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.certificates
    WHERE name=N'DBAOps_SecurityCert'
)
BEGIN
    CREATE CERTIFICATE [DBAOps_SecurityCert]
    FROM FILE='C:\Temp\DBAOps_SecurityCert.cer';
END;
GO

IF DATABASE_PRINCIPAL_ID(N'DBAOps_SecurityCertUser') IS NULL
BEGIN
    CREATE USER [DBAOps_SecurityCertUser]
    FROM CERTIFICATE [DBAOps_SecurityCert];
END;
GO

GRANT ALTER ANY USER TO [DBAOps_SecurityCertUser];
GRANT ALTER ON ROLE::[db_datareader] TO [DBAOps_SecurityCertUser];
GRANT ALTER ON ROLE::[db_datawriter] TO [DBAOps_SecurityCertUser];
GO

/*
A10.7 - backup; DOMYŚLNIE WYŁĄCZONY.
Jeżeli świadomie ustawisz AllowBackup=1:

IF NOT EXISTS
(
    SELECT 1 FROM sys.certificates
    WHERE name=N'DBAOps_BackupCert'
)
BEGIN
    CREATE CERTIFICATE [DBAOps_BackupCert]
    FROM FILE='C:\Temp\DBAOps_BackupCert.cer';
END;

IF DATABASE_PRINCIPAL_ID(N'DBAOps_BackupCertUser') IS NULL
BEGIN
    CREATE USER [DBAOps_BackupCertUser]
    FROM CERTIFICATE [DBAOps_BackupCert];
END;

ALTER ROLE [db_backupoperator]
ADD MEMBER [DBAOps_BackupCertUser];
GO
*/

/* A10.8 - kontrola końcowa */
SELECT
    r.name AS DatabaseRole,
    m.name AS MemberName
FROM sys.database_role_members drm
JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
WHERE m.name=N'SQLLAB\Developer'
ORDER BY r.name;
GO

/*
Oczekiwane:
    db_datareader
    db_datawriter
    db_executor

Nie powinno być:
    db_owner
    db_ddladmin
    db_securityadmin
    db_accessadmin
*/

/* ###########################################################################
   B. SEKCJA DLA DEVELOPERA
   ########################################################################### */

/* ============================================================================
   B1. NORMALNA PRACA Z DANYMI
   Dzięki db_datareader + db_datawriter:
   ============================================================================ */
/*
USE [baza];

SELECT * FROM dbo.SomeTable;
INSERT dbo.SomeTable(...) VALUES(...);
UPDATE dbo.SomeTable SET ... WHERE ...;
DELETE dbo.SomeTable WHERE ...;
*/

/* ============================================================================
   B1A. WYKONYWANIE PROCEDUR SKŁADOWANYCH

   SQLLAB\Developer jest członkiem db_executor.
   db_executor ma:
       GRANT EXECUTE ON SCHEMA::dbo

   Dzięki temu developer może wykonywać istniejące oraz przyszłe procedury
   w schemacie dbo bez db_owner.
   ============================================================================ */
/*
USE [baza];
GO

EXEC dbo.usp_MojaProcedura
    @Id = 1;
GO
*/

/* ============================================================================
   B2. CREATE TABLE
   ============================================================================ */
USE [DBA_Operations];
GO

/*
EXEC ops.usp_CreateTable
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @TableName=N'CustomerDemo',
    @ColumnsJson=N'
    [
      {"name":"Id","type":"int","nullable":false,"identity":true},
      {"name":"Name","type":"nvarchar","length":200,"nullable":false},
      {"name":"Email","type":"nvarchar","length":320,"nullable":true},
      {"name":"CreatedAt","type":"datetime2","nullable":false}
    ]';
GO
*/

/* ============================================================================
   B3. ADD COLUMN
   ============================================================================ */
/*
EXEC ops.usp_AddColumn
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @TableName=N'CustomerDemo',
    @ColumnName=N'IsActive',
    @DataType=N'bit',
    @Nullable=1;
GO
*/

/* ============================================================================
   B4. DROP COLUMN
   ============================================================================ */
/*
EXEC ops.usp_DropColumn
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @TableName=N'CustomerDemo',
    @ColumnName=N'IsActive';
GO
*/

/* ============================================================================
   B5. CREATE OR ALTER VIEW
   ============================================================================ */
/*
EXEC ops.usp_CreateOrAlterView
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @ViewName=N'vCustomerDemo',
    @SelectBody=N'
        SELECT Id, Name, Email, CreatedAt
        FROM dbo.CustomerDemo
    ';
GO
*/

/* ============================================================================
   B6. CREATE OR ALTER PROCEDURE
   ============================================================================ */
/*
EXEC ops.usp_CreateOrAlterProcedure
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @ProcedureName=N'usp_CustomerDemo_Get',
    @ParametersJson=N'
    [
      {"name":"@Id","type":"int","output":false}
    ]',
    @Body=N'
        SELECT Id, Name, Email, CreatedAt
        FROM dbo.CustomerDemo
        WHERE Id = @Id;
    ';
GO
*/

/* ============================================================================
   B7. DROP PROCEDURE / VIEW / TABLE
   ============================================================================ */
/*
EXEC ops.usp_DropProcedure
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @ProcedureName=N'usp_CustomerDemo_Get';

EXEC ops.usp_DropView
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @ViewName=N'vCustomerDemo';

EXEC ops.usp_DropTable
    @DatabaseName=N'baza',
    @SchemaName=N'dbo',
    @TableName=N'CustomerDemo';
GO
*/

/* ============================================================================
   B8. CREATE USER DLA ISTNIEJĄCEGO LOGINU
   Login serwerowy tworzy DBA / jest zarządzany przez AD.
   Developer tworzy tylko USER w dozwolonej bazie.
   ============================================================================ */
/*
EXEC ops.usp_CreateDatabaseUser
    @DatabaseName=N'baza',
    @LoginName=N'SQLLAB\zenek',
    @UserName=N'SQLLAB\zenek';
GO
*/

/* ============================================================================
   B9. ADD USER TO db_datareader
   ============================================================================ */
/*
EXEC ops.usp_AddUserToDatabaseRole
    @DatabaseName=N'baza',
    @UserName=N'SQLLAB\zenek',
    @RoleName=N'db_datareader';
GO
*/

/* ============================================================================
   B10. ADD USER TO db_datawriter
   ============================================================================ */
/*
EXEC ops.usp_AddUserToDatabaseRole
    @DatabaseName=N'baza',
    @UserName=N'SQLLAB\zenek',
    @RoleName=N'db_datawriter';
GO
*/

/* ============================================================================
   B11. REMOVE USER FROM ROLE
   ============================================================================ */
/*
EXEC ops.usp_RemoveUserFromDatabaseRole
    @DatabaseName=N'baza',
    @UserName=N'SQLLAB\zenek',
    @RoleName=N'db_datawriter';
GO
*/

/* ============================================================================
   B12. DROP DATABASE USER
   ============================================================================ */
/*
EXEC ops.usp_DropDatabaseUser
    @DatabaseName=N'baza',
    @UserName=N'SQLLAB\zenek';
GO
*/

/* ============================================================================
   B13. BACKUP - tylko jeśli DBA świadomie włączył AllowBackup
   ============================================================================ */
/*
EXEC ops.usp_BackupDatabase
    @DatabaseName=N'baza';
GO
*/

/* ============================================================================
   B14. AUDYT WŁASNYCH OPERACJI
   ============================================================================ */
/*
EXEC ops.usp_MyOperationAudit
    @Top=100;
GO
*/

/* ============================================================================
   B15. OPERACJE, KTÓRE MAJĄ BYĆ ZABLOKOWANE BEZPOŚREDNIO
   ============================================================================ */
/*
USE [baza];

-- powinno być DENIED:
CREATE TABLE dbo.DirectCreate(Id int);
ALTER TABLE dbo.SomeTable ADD X int;
DROP TABLE dbo.SomeTable;
CREATE USER [SQLLAB\ktos] FOR LOGIN [SQLLAB\ktos];
ALTER ROLE [db_datareader] ADD MEMBER [SQLLAB\ktos];

-- grupa nie jest db_owner:
SELECT IS_ROLEMEMBER(N'db_owner',N'SQLLAB\Developer');

-- ale może wykonywać procedury w dbo dzięki db_executor:
EXEC dbo.usp_MojaProcedura;
*/

/* ============================================================================
   B16. OPERACJE ZABLOKOWANE RÓWNIEŻ PRZEZ WRAPPERY
   ============================================================================ */
/*
-- niezarządzana baza:
EXEC DBA_Operations.ops.usp_AddColumn
    @DatabaseName=N'InnaBaza',
    @SchemaName=N'dbo',
    @TableName=N'X',
    @ColumnName=N'Y',
    @DataType=N'int';

-- niedozwolona rola:
EXEC DBA_Operations.ops.usp_AddUserToDatabaseRole
    @DatabaseName=N'baza',
    @UserName=N'SQLLAB\zenek',
    @RoleName=N'db_owner';
*/

/*
===============================================================================
ZASADA OPERACYJNA

Nowy developer:
    AD -> dodaj użytkownika do SQLLAB\Developer.
    SQL Server -> ZERO zmian.

Developer odchodzi:
    AD -> usuń z SQLLAB\Developer.
    SQL Server -> ZERO zmian.

Nowa baza:
    tylko administrator onboarduje bazę do DBA_Operations.
===============================================================================
*/
