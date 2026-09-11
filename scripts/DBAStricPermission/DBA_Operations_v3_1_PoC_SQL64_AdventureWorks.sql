
/*
===============================================================================
DBA_Operations v3.1 - PoC
SQL64 + AdventureWorks + SQLLAB\Developer + SQLLAB\devPOC
===============================================================================

CEL PoC
-------
1. Utworzyć w AD:
      SQLLAB\devPOC
      SQLLAB\Developer
   oraz dodać użytkownika do grupy.

2. Na SQL64:
      - wdrożyć DBA_Operations v3.1,
      - utworzyć tylko jeden login SQL Server:
            SQLLAB\Developer
      - onboardować bazę AdventureWorks,
      - nadać grupie:
            db_datareader
            db_datawriter
            db_executor
      - zainstalować certyfikaty DDL i Security,
      - NIE nadawać db_owner.

3. Zalogować się do SSMS jako:
      SQLLAB\devPOC

4. Sprawdzić:
      - SELECT / INSERT / UPDATE / DELETE
      - EXECUTE procedur dbo.*
      - brak bezpośredniego DDL
      - DDL przez DBA_Operations
      - Database Security przez DBA_Operations
      - audyt ORIGINAL_LOGIN()

===============================================================================
WAŻNE
===============================================================================

Ten plik jest runbookiem PoC.

Wykonuj sekcje dokładnie w podanej kolejności.

SKRYPTY Z REPO:
  scripts\DBAStricPermission\DBA_Operations_v3_1_FULL_Deployment.sql
  scripts\DBAStricPermission\DBA_Operations_v3_1_Admin_Config_and_Developer_Usage.sql

Dla PoC potrzebny jest przede wszystkim:
  DBA_Operations_v3_1_FULL_Deployment.sql

Instancja:
  SQL64

Baza:
  AdventureWorks

Grupa AD:
  SQLLAB\Developer

Użytkownik testowy:
  SQLLAB\devPOC

===============================================================================
FAZA 0 - ACTIVE DIRECTORY
===============================================================================

GDZIE URUCHOMIĆ:
  PowerShell jako administrator na:
    - kontrolerze domeny
    LUB
    - stacji administracyjnej z RSAT / ActiveDirectory module

WYMAGANIA:
  Import-Module ActiveDirectory

UWAGA:
  Musisz mieć prawa do tworzenia kont i grup w odpowiednim OU.

Poniższe komendy są PowerShell - NIE uruchamiaj ich w SSMS.

----------------------------------------------------------------------------
0.1. Sprawdzenie modułu
----------------------------------------------------------------------------

Import-Module ActiveDirectory

Get-Module ActiveDirectory

----------------------------------------------------------------------------
0.2. Ustaw właściwe OU
----------------------------------------------------------------------------

PRZYKŁAD:
  OU=LabUsers,DC=sqllab,DC=local
  OU=LabGroups,DC=sqllab,DC=local

ZMIEŃ poniższe ścieżki na swoje OU:

$UserOU  = "OU=LabUsers,DC=sqllab,DC=local"
$GroupOU = "OU=LabGroups,DC=sqllab,DC=local"

----------------------------------------------------------------------------
0.3. Utworzenie grupy SQLLAB\Developer
----------------------------------------------------------------------------

if (-not (Get-ADGroup -Filter "SamAccountName -eq 'Developer'" -ErrorAction SilentlyContinue)) {

    New-ADGroup `
        -Name "Developer" `
        -SamAccountName "Developer" `
        -GroupCategory Security `
        -GroupScope Global `
        -Path $GroupOU `
        -Description "SQL Server developers - DBA_Operations PoC"
}

----------------------------------------------------------------------------
0.4. Utworzenie konta SQLLAB\devPOC
----------------------------------------------------------------------------

$Password = Read-Host "Password for SQLLAB\devPOC" -AsSecureString

if (-not (Get-ADUser -Filter "SamAccountName -eq 'devPOC'" -ErrorAction SilentlyContinue)) {

    New-ADUser `
        -Name "devPOC" `
        -SamAccountName "devPOC" `
        -UserPrincipalName "devPOC@sqllab.local" `
        -Path $UserOU `
        -AccountPassword $Password `
        -Enabled $true `
        -ChangePasswordAtLogon $false `
        -PasswordNeverExpires $true `
        -Description "DBA_Operations v3.1 PoC developer account"
}

----------------------------------------------------------------------------
0.5. Dodanie SQLLAB\devPOC do SQLLAB\Developer
----------------------------------------------------------------------------

Add-ADGroupMember `
    -Identity "Developer" `
    -Members "devPOC"

----------------------------------------------------------------------------
0.6. Weryfikacja
----------------------------------------------------------------------------

Get-ADGroupMember -Identity "Developer"

Get-ADUser devPOC -Properties MemberOf |
    Select-Object SamAccountName, MemberOf

OCZEKUJEMY:
  devPOC jest członkiem grupy Developer

===============================================================================
FAZA 1 - SQL64 - WDROŻENIE DBA_Operations v3.1
===============================================================================

GDZIE URUCHOMIĆ:
  SSMS
  Server: SQL64
  Authentication: Windows Authentication
  Konto: sysadmin

SKRYPT:
  scripts\DBAStricPermission\DBA_Operations_v3_1_FULL_Deployment.sql

PRZED URUCHOMIENIEM:
  1. sprawdź hasło DMK,
  2. sprawdź:
       C:\Temp\
  3. sprawdź BackupRoot,
  4. upewnij się, że konto usługi SQL Server może zapisać/odczytać certyfikaty.

Po wykonaniu powinny istnieć:
  DBA_Operations
  DBAOps_DdlCert
  DBAOps_SecurityCert
  DBAOps_BackupCert

===============================================================================
FAZA 2 - SQL64 - KONFIGURACJA GRUPY AD
===============================================================================
*/

USE [master];
GO

IF SUSER_ID(N'SQLLAB\Developer') IS NULL
BEGIN
    CREATE LOGIN [SQLLAB\Developer]
    FROM WINDOWS;
END;
GO

SELECT
    name,
    type_desc
FROM sys.server_principals
WHERE name = N'SQLLAB\Developer';
GO

/*
OCZEKUJEMY:
  WINDOWS_GROUP
*/

/* ============================================================================
FAZA 3 - SQL64 - SQLLAB\Developer W DBA_Operations
============================================================================ */

USE [DBA_Operations];
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
    JOIN sys.database_principals r
      ON r.principal_id = drm.role_principal_id
    JOIN sys.database_principals m
      ON m.principal_id = drm.member_principal_id
    WHERE r.name = N'DBA_DeveloperDdlOperator'
      AND m.name = N'SQLLAB\Developer'
)
BEGIN
    ALTER ROLE [DBA_DeveloperDdlOperator]
    ADD MEMBER [SQLLAB\Developer];
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r
      ON r.principal_id = drm.role_principal_id
    JOIN sys.database_principals m
      ON m.principal_id = drm.member_principal_id
    WHERE r.name = N'DBA_DeveloperSecurityOperator'
      AND m.name = N'SQLLAB\Developer'
)
BEGIN
    ALTER ROLE [DBA_DeveloperSecurityOperator]
    ADD MEMBER [SQLLAB\Developer];
END;
GO

/*
Backup w PoC pozostawiamy wyłączony.

NIE wykonujemy:
ALTER ROLE [DBA_DeveloperBackupOperator]
ADD MEMBER [SQLLAB\Developer];
*/

/* ============================================================================
FAZA 4 - SQL64 - ONBOARDING AdventureWorks
============================================================================ */

USE [DBA_Operations];
GO

MERGE dbo.ManagedDatabase AS T
USING
(
    SELECT
        N'AdventureWorks' AS DatabaseName,
        CONVERT(bit,1) AS AllowDdl,
        CONVERT(bit,1) AS AllowSecurity,
        CONVERT(bit,0) AS AllowBackup,
        CONVERT(bit,1) AS IsEnabled,
        N'PoC SQL64 / SQLLAB\Developer' AS Comment
) AS S
ON T.DatabaseName = S.DatabaseName

WHEN MATCHED THEN
    UPDATE SET
        AllowDdl      = S.AllowDdl,
        AllowSecurity = S.AllowSecurity,
        AllowBackup   = S.AllowBackup,
        IsEnabled     = S.IsEnabled,
        Comment       = S.Comment

WHEN NOT MATCHED THEN
    INSERT
    (
        DatabaseName,
        AllowDdl,
        AllowSecurity,
        AllowBackup,
        IsEnabled,
        Comment
    )
    VALUES
    (
        S.DatabaseName,
        S.AllowDdl,
        S.AllowSecurity,
        S.AllowBackup,
        S.IsEnabled,
        S.Comment
    );
GO

SELECT *
FROM dbo.ManagedDatabase
WHERE DatabaseName = N'AdventureWorks';
GO

/* ============================================================================
FAZA 5 - AdventureWorks - USER SQLLAB\Developer
============================================================================ */

USE [AdventureWorks];
GO

IF DATABASE_PRINCIPAL_ID(N'SQLLAB\Developer') IS NULL
BEGIN
    CREATE USER [SQLLAB\Developer]
    FOR LOGIN [SQLLAB\Developer];
END;
GO

/* ============================================================================
FAZA 6 - AdventureWorks - db_datareader
============================================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r
      ON r.principal_id = drm.role_principal_id
    JOIN sys.database_principals m
      ON m.principal_id = drm.member_principal_id
    WHERE r.name = N'db_datareader'
      AND m.name = N'SQLLAB\Developer'
)
BEGIN
    ALTER ROLE [db_datareader]
    ADD MEMBER [SQLLAB\Developer];
END;
GO

/* ============================================================================
FAZA 7 - AdventureWorks - db_datawriter
============================================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r
      ON r.principal_id = drm.role_principal_id
    JOIN sys.database_principals m
      ON m.principal_id = drm.member_principal_id
    WHERE r.name = N'db_datawriter'
      AND m.name = N'SQLLAB\Developer'
)
BEGIN
    ALTER ROLE [db_datawriter]
    ADD MEMBER [SQLLAB\Developer];
END;
GO

/* ============================================================================
FAZA 8 - AdventureWorks - db_executor
============================================================================ */

IF DATABASE_PRINCIPAL_ID(N'db_executor') IS NULL
BEGIN
    CREATE ROLE [db_executor]
    AUTHORIZATION [dbo];
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
    JOIN sys.database_principals r
      ON r.principal_id = drm.role_principal_id
    JOIN sys.database_principals m
      ON m.principal_id = drm.member_principal_id
    WHERE r.name = N'db_executor'
      AND m.name = N'SQLLAB\Developer'
)
BEGIN
    ALTER ROLE [db_executor]
    ADD MEMBER [SQLLAB\Developer];
END;
GO

/* ============================================================================
FAZA 9 - AdventureWorks - CERTYFIKAT DDL
============================================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.certificates
    WHERE name = N'DBAOps_DdlCert'
)
BEGIN
    CREATE CERTIFICATE [DBAOps_DdlCert]
    FROM FILE = 'C:\Temp\DBAOps_DdlCert.cer';
END;
GO

IF DATABASE_PRINCIPAL_ID(N'DBAOps_DdlCertUser') IS NULL
BEGIN
    CREATE USER [DBAOps_DdlCertUser]
    FROM CERTIFICATE [DBAOps_DdlCert];
END;
GO

GRANT ALTER
ON SCHEMA::[dbo]
TO [DBAOps_DdlCertUser];
GO

GRANT CREATE TABLE
TO [DBAOps_DdlCertUser];
GO

GRANT CREATE VIEW
TO [DBAOps_DdlCertUser];
GO

GRANT CREATE PROCEDURE
TO [DBAOps_DdlCertUser];
GO

/* ============================================================================
FAZA 10 - AdventureWorks - CERTYFIKAT SECURITY
============================================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.certificates
    WHERE name = N'DBAOps_SecurityCert'
)
BEGIN
    CREATE CERTIFICATE [DBAOps_SecurityCert]
    FROM FILE = 'C:\Temp\DBAOps_SecurityCert.cer';
END;
GO

IF DATABASE_PRINCIPAL_ID(N'DBAOps_SecurityCertUser') IS NULL
BEGIN
    CREATE USER [DBAOps_SecurityCertUser]
    FROM CERTIFICATE [DBAOps_SecurityCert];
END;
GO

GRANT ALTER ANY USER
TO [DBAOps_SecurityCertUser];
GO

GRANT ALTER
ON ROLE::[db_datareader]
TO [DBAOps_SecurityCertUser];
GO

GRANT ALTER
ON ROLE::[db_datawriter]
TO [DBAOps_SecurityCertUser];
GO

/* ============================================================================
FAZA 11 - AdventureWorks - OBIEKTY TESTOWE DBA
============================================================================ */

USE [AdventureWorks];
GO

IF OBJECT_ID(N'dbo.PoC_DeveloperData',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PoC_DeveloperData
    (
        Id int IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_PoC_DeveloperData PRIMARY KEY,
        Name nvarchar(100) NOT NULL,
        CreatedAt datetime2(0) NOT NULL
            CONSTRAINT DF_PoC_DeveloperData_CreatedAt DEFAULT sysdatetime()
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_PoC_DeveloperData_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        Name,
        CreatedAt
    FROM dbo.PoC_DeveloperData
    ORDER BY Id;
END;
GO

/*
===============================================================================
FAZA 12 - WERYFIKACJA PRZED LOGOWANIEM JAKO devPOC
===============================================================================
*/

SELECT
    r.name AS DatabaseRole,
    m.name AS MemberName
FROM sys.database_role_members drm
JOIN sys.database_principals r
  ON r.principal_id = drm.role_principal_id
JOIN sys.database_principals m
  ON m.principal_id = drm.member_principal_id
WHERE m.name = N'SQLLAB\Developer'
ORDER BY r.name;
GO

/*
OCZEKUJEMY:
  db_datareader
  db_datawriter
  db_executor

NIE:
  db_owner
  db_ddladmin
  db_securityadmin
*/

/*
===============================================================================
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
STOP
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Od tego miejsca NIE wykonuj jako sysadmin.

1. Wyloguj/zamknij SSMS.
2. Uruchom SSMS jako:
       SQLLAB\devPOC

   Możesz:
       - zalogować się do Windows jako SQLLAB\devPOC
       LUB
       - uruchomić SSMS przez "Run as different user"

3. Połącz się:
       Server: SQL64
       Authentication: Windows Authentication

4. Otwórz nowe okno query.

Dalsze sekcje wykonuje:
       SQLLAB\devPOC

===============================================================================
FAZA 13 - DEV - IDENTYFIKACJA
===============================================================================
*/

SELECT
    ORIGINAL_LOGIN() AS OriginalLogin,
    SUSER_SNAME() AS SessionLogin,
    SYSTEM_USER AS SystemUser;
GO

/*
OCZEKUJEMY:
  SQLLAB\devPOC
*/

/* ============================================================================
FAZA 14 - DEV - TEST RÓL
============================================================================ */

USE [AdventureWorks];
GO

SELECT
    IS_ROLEMEMBER(N'db_datareader')   AS IsDataReader,
    IS_ROLEMEMBER(N'db_datawriter')   AS IsDataWriter,
    IS_ROLEMEMBER(N'db_executor')     AS IsExecutor,
    IS_ROLEMEMBER(N'db_owner')        AS IsDbOwner,
    IS_ROLEMEMBER(N'db_ddladmin')     AS IsDdlAdmin,
    IS_ROLEMEMBER(N'db_securityadmin') AS IsSecurityAdmin;
GO

/*
OCZEKUJEMY:
  IsDataReader    = 1
  IsDataWriter    = 1
  IsExecutor      = 1
  IsDbOwner       = 0
  IsDdlAdmin      = 0
  IsSecurityAdmin = 0
*/

/* ============================================================================
FAZA 15 - DEV - SELECT
============================================================================ */

SELECT TOP (10) *
FROM dbo.PoC_DeveloperData;
GO

/* ============================================================================
FAZA 16 - DEV - INSERT
============================================================================ */

INSERT dbo.PoC_DeveloperData(Name)
VALUES
(N'Inserted by SQLLAB\devPOC');
GO

/* ============================================================================
FAZA 17 - DEV - UPDATE
============================================================================ */

UPDATE dbo.PoC_DeveloperData
SET Name = N'Updated by SQLLAB\devPOC'
WHERE Name = N'Inserted by SQLLAB\devPOC';
GO

/* ============================================================================
FAZA 18 - DEV - EXECUTE PROCEDURY
============================================================================ */

EXEC dbo.usp_PoC_DeveloperData_List;
GO

/*
OCZEKUJEMY:
  procedura działa dzięki db_executor
*/

/* ============================================================================
FAZA 19 - DEV - DELETE
============================================================================ */

DELETE dbo.PoC_DeveloperData
WHERE Name = N'Updated by SQLLAB\devPOC';
GO

/* ============================================================================
FAZA 20 - DEV - TEST NEGATYWNY:
          BEZPOŚREDNI CREATE TABLE MA SIĘ NIE UDAĆ
============================================================================ */

/*
USE [AdventureWorks];
GO

CREATE TABLE dbo.PoC_ShouldFail
(
    Id int
);
GO

OCZEKUJEMY:
  CREATE TABLE permission denied
*/

/* ============================================================================
FAZA 21 - DEV - TEST NEGATYWNY:
          BEZPOŚREDNI ALTER TABLE MA SIĘ NIE UDAĆ
============================================================================ */

/*
ALTER TABLE dbo.PoC_DeveloperData
ADD DirectColumnShouldFail int NULL;
GO

OCZEKUJEMY:
  ALTER permission denied
*/

/* ============================================================================
FAZA 22 - DEV - TEST POZYTYWNY:
          CREATE TABLE PRZEZ DBA_Operations
============================================================================ */

USE [DBA_Operations];
GO

EXEC ops.usp_CreateTable
    @DatabaseName = N'AdventureWorks',
    @SchemaName   = N'dbo',
    @TableName    = N'PoC_WrapperTable',
    @ColumnsJson  = N'
    [
      {
        "name":"Id",
        "type":"int",
        "nullable":false,
        "identity":true
      },
      {
        "name":"Name",
        "type":"nvarchar",
        "length":200,
        "nullable":true
      }
    ]';
GO

/* ============================================================================
FAZA 23 - DEV - ADD COLUMN PRZEZ DBA_Operations
============================================================================ */

EXEC ops.usp_AddColumn
    @DatabaseName = N'AdventureWorks',
    @SchemaName   = N'dbo',
    @TableName    = N'PoC_WrapperTable',
    @ColumnName   = N'CreatedAt',
    @DataType     = N'datetime2',
    @Nullable     = 1;
GO

/* ============================================================================
FAZA 24 - DEV - CREATE VIEW PRZEZ DBA_Operations
============================================================================ */

EXEC ops.usp_CreateOrAlterView
    @DatabaseName = N'AdventureWorks',
    @SchemaName   = N'dbo',
    @ViewName     = N'vPoC_WrapperTable',
    @SelectBody   = N'
        SELECT
            Id,
            Name,
            CreatedAt
        FROM dbo.PoC_WrapperTable
    ';
GO

/* ============================================================================
FAZA 25 - DEV - CREATE PROCEDURE PRZEZ DBA_Operations
============================================================================ */

EXEC ops.usp_CreateOrAlterProcedure
    @DatabaseName  = N'AdventureWorks',
    @SchemaName    = N'dbo',
    @ProcedureName = N'usp_PoC_WrapperTable_List',
    @ParametersJson = N'[]',
    @Body = N'
        SELECT
            Id,
            Name,
            CreatedAt
        FROM dbo.PoC_WrapperTable
        ORDER BY Id;
    ';
GO

/* ============================================================================
FAZA 26 - DEV - URUCHOMIENIE NOWEJ PROCEDURY
============================================================================ */

USE [AdventureWorks];
GO

EXEC dbo.usp_PoC_WrapperTable_List;
GO

/*
To powinno działać automatycznie, ponieważ:
  SQLLAB\Developer -> db_executor
  db_executor -> EXECUTE ON SCHEMA::dbo
*/

/* ============================================================================
FAZA 27 - DEV - TEST SECURITY
          Potrzebujemy istniejącego loginu testowego.

UWAGA:
  Login serwerowy musi utworzyć DBA.
  Developer NIE tworzy loginów.
============================================================================ */

/*
PRZERWIJ TUTAJ i jako DBA utwórz wcześniej np.:

USE master;
CREATE LOGIN [SQLLAB\readerPOC] FROM WINDOWS;

Jeśli konto nie istnieje w AD, najpierw utwórz je w AD.
*/

/* ============================================================================
FAZA 28 - DEV - CREATE DATABASE USER
============================================================================ */

/*
USE [DBA_Operations];
GO

EXEC ops.usp_CreateDatabaseUser
    @DatabaseName = N'AdventureWorks',
    @LoginName    = N'SQLLAB\readerPOC',
    @UserName     = N'SQLLAB\readerPOC';
GO
*/

/* ============================================================================
FAZA 29 - DEV - ADD USER TO db_datareader
============================================================================ */

/*
EXEC ops.usp_AddUserToDatabaseRole
    @DatabaseName = N'AdventureWorks',
    @UserName     = N'SQLLAB\readerPOC',
    @RoleName     = N'db_datareader';
GO
*/

/* ============================================================================
FAZA 30 - DEV - NEGATYWNY TEST db_owner
============================================================================ */

/*
EXEC ops.usp_AddUserToDatabaseRole
    @DatabaseName = N'AdventureWorks',
    @UserName     = N'SQLLAB\readerPOC',
    @RoleName     = N'db_owner';
GO

OCZEKUJEMY:
  odrzucenie - rola nie jest w AllowedDatabaseRole
*/

/* ============================================================================
FAZA 31 - DEV - DROP COLUMN PRZEZ WRAPPER
============================================================================ */

USE [DBA_Operations];
GO

EXEC ops.usp_DropColumn
    @DatabaseName = N'AdventureWorks',
    @SchemaName   = N'dbo',
    @TableName    = N'PoC_WrapperTable',
    @ColumnName   = N'CreatedAt';
GO

/* ============================================================================
FAZA 32 - DEV - DROP PROCEDURE / VIEW / TABLE PRZEZ WRAPPERY
============================================================================ */

EXEC ops.usp_DropProcedure
    @DatabaseName  = N'AdventureWorks',
    @SchemaName    = N'dbo',
    @ProcedureName = N'usp_PoC_WrapperTable_List';
GO

EXEC ops.usp_DropView
    @DatabaseName = N'AdventureWorks',
    @SchemaName   = N'dbo',
    @ViewName     = N'vPoC_WrapperTable';
GO

EXEC ops.usp_DropTable
    @DatabaseName = N'AdventureWorks',
    @SchemaName   = N'dbo',
    @TableName    = N'PoC_WrapperTable';
GO

/* ============================================================================
FAZA 33 - DEV - AUDYT WŁASNYCH OPERACJI
============================================================================ */

EXEC ops.usp_MyOperationAudit
    @Top = 100;
GO

/*
Sprawdź szczególnie:
  OriginalLogin = SQLLAB\devPOC
*/

/*
===============================================================================
FAZA 34 - DBA - AUDYT GLOBALNY
===============================================================================

Zamknij sesję devPOC.

Połącz się ponownie do SQL64 jako sysadmin.
*/

USE [DBA_Operations];
GO

EXEC ops.usp_AllOperationAudit
    @Top = 500;
GO

/* ============================================================================
FAZA 35 - DBA - WERYFIKACJA, ŻE SQLLAB\Developer NIE MA db_owner
============================================================================ */

USE [AdventureWorks];
GO

SELECT
    r.name AS DatabaseRole,
    m.name AS MemberName
FROM sys.database_role_members drm
JOIN sys.database_principals r
  ON r.principal_id = drm.role_principal_id
JOIN sys.database_principals m
  ON m.principal_id = drm.member_principal_id
WHERE m.name = N'SQLLAB\Developer'
ORDER BY r.name;
GO

/*
OCZEKUJEMY:
  db_datareader
  db_datawriter
  db_executor
*/

/*
===============================================================================
FAZA 36 - CLEANUP POC
===============================================================================

Wykonuj tylko jeśli chcesz usunąć artefakty PoC.

UWAGA:
  Nie usuwaj DBA_Operations, jeśli chcesz dalej rozwijać rozwiązanie.
*/

/*
USE [AdventureWorks];
GO

IF OBJECT_ID(N'dbo.usp_PoC_DeveloperData_List',N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_PoC_DeveloperData_List;

IF OBJECT_ID(N'dbo.PoC_DeveloperData',N'U') IS NOT NULL
    DROP TABLE dbo.PoC_DeveloperData;
GO

USE [DBA_Operations];
GO

DELETE dbo.ManagedDatabase
WHERE DatabaseName = N'AdventureWorks';
GO

USE [AdventureWorks];
GO

IF DATABASE_PRINCIPAL_ID(N'SQLLAB\Developer') IS NOT NULL
    DROP USER [SQLLAB\Developer];
GO

IF DATABASE_PRINCIPAL_ID(N'DBAOps_DdlCertUser') IS NOT NULL
    DROP USER [DBAOps_DdlCertUser];

IF EXISTS
(
    SELECT 1 FROM sys.certificates
    WHERE name=N'DBAOps_DdlCert'
)
    DROP CERTIFICATE [DBAOps_DdlCert];
GO

IF DATABASE_PRINCIPAL_ID(N'DBAOps_SecurityCertUser') IS NOT NULL
    DROP USER [DBAOps_SecurityCertUser];

IF EXISTS
(
    SELECT 1 FROM sys.certificates
    WHERE name=N'DBAOps_SecurityCert'
)
    DROP CERTIFICATE [DBAOps_SecurityCert];
GO

IF DATABASE_PRINCIPAL_ID(N'db_executor') IS NOT NULL
    DROP ROLE [db_executor];
GO

USE [DBA_Operations];
GO

IF DATABASE_PRINCIPAL_ID(N'SQLLAB\Developer') IS NOT NULL
    DROP USER [SQLLAB\Developer];
GO

USE [master];
GO

IF SUSER_ID(N'SQLLAB\Developer') IS NOT NULL
    DROP LOGIN [SQLLAB\Developer];
GO
*/

/*
===============================================================================
FAZA 37 - CLEANUP AD
===============================================================================

PowerShell jako administrator AD:

Remove-ADGroupMember `
    -Identity "Developer" `
    -Members "devPOC" `
    -Confirm:$false

Remove-ADUser `
    -Identity "devPOC" `
    -Confirm:$false

Remove-ADGroup `
    -Identity "Developer" `
    -Confirm:$false

UWAGA:
  Wykonaj tylko jeśli grupa Developer została utworzona wyłącznie dla PoC.

===============================================================================
OCZEKIWANY WYNIK POC
===============================================================================

SQLLAB\devPOC:

  przez grupę SQLLAB\Developer:

    AdventureWorks:
      YES  SELECT
      YES  INSERT
      YES  UPDATE
      YES  DELETE
      YES  EXECUTE dbo.*

      NO   db_owner
      NO   db_ddladmin
      NO   db_securityadmin

      NO   direct CREATE TABLE
      NO   direct ALTER TABLE
      NO   direct DROP TABLE
      NO   direct CREATE USER
      NO   direct ALTER ROLE

    DBA_Operations:
      YES  controlled CREATE TABLE
      YES  controlled DROP TABLE
      YES  controlled ADD COLUMN
      YES  controlled DROP COLUMN
      YES  controlled CREATE/ALTER VIEW
      YES  controlled DROP VIEW
      YES  controlled CREATE/ALTER PROCEDURE
      YES  controlled DROP PROCEDURE
      YES  controlled CREATE DATABASE USER
      YES  controlled ADD USER -> db_datareader
      YES  controlled ADD USER -> db_datawriter

      NO   db_owner assignment

AUDYT:
  ORIGINAL_LOGIN() = SQLLAB\devPOC

===============================================================================
KONIEC PoC
===============================================================================
*/
