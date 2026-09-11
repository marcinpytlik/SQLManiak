/*
===============================================================================
DBA_Operations v3 - GROUP BASED DEVELOPER DELEGATION
SQL Server 2016+
===============================================================================

ARCHITEKTURA
------------
AD group:
    SQLLAB\Developer

Bezpośrednio w bazach aplikacyjnych:
    db_datareader   (opcjonalnie, rekomendowane dla środowisk DEV/TEST)
    db_datawriter
    db_executor     (własna rola: EXECUTE ON SCHEMA::dbo)

BRAK:
    db_owner
    db_ddladmin
    db_securityadmin
    db_accessadmin
    sysadmin
    securityadmin
    dbcreator

Operacje administracyjne:
    SQLLAB\Developer
        -> EXECUTE na kontrolowanych wrapperach w DBA_Operations
        -> module signing
        -> osobne certyfikaty funkcjonalne
        -> minimalne prawa w zarządzanych bazach

CERTYFIKATY:
    DBAOps_DdlCert       - DDL w bazie
    DBAOps_SecurityCert  - CREATE/DROP USER, role bazodanowe
    DBAOps_BackupCert    - BACKUP DATABASE

WAŻNE:
  1. Uruchom jako sysadmin.
  2. Zmień hasło DMK.
  3. Zmień ścieżkę eksportu certyfikatów.
  4. Po ALTER PROCEDURE podpis modułu znika - należy podpisać ponownie.
  5. TRUSTWORTHY pozostaje OFF.
  6. Ten skrypt tworzy mechanizm. Konfiguracja grupy i baz jest w drugim pliku.
===============================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   1. DBA_Operations
   ============================================================================ */
USE [master];
GO

IF DB_ID(N'DBA_Operations') IS NULL
    CREATE DATABASE [DBA_Operations];
GO

ALTER DATABASE [DBA_Operations] SET TRUSTWORTHY OFF;
ALTER DATABASE [DBA_Operations] SET DB_CHAINING OFF;
ALTER DATABASE [DBA_Operations] SET COMPATIBILITY_LEVEL = 130;
GO

USE [DBA_Operations];
GO

IF SCHEMA_ID(N'ops') IS NULL
    EXEC(N'CREATE SCHEMA [ops] AUTHORIZATION [dbo];');
GO

/* ============================================================================
   2. DATABASE MASTER KEY
   ============================================================================ */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.symmetric_keys
    WHERE name = N'##MS_DatabaseMasterKey##'
)
BEGIN
    CREATE MASTER KEY
    ENCRYPTION BY PASSWORD = 'CHANGE_ME_DBAOPS_V3_DMK_StrongPassword_2026!';
END;
GO

/* ============================================================================
   3. CERTYFIKATY FUNKCJONALNE
   ============================================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'DBAOps_DdlCert')
BEGIN
    CREATE CERTIFICATE [DBAOps_DdlCert]
    WITH SUBJECT = N'DBA_Operations v3 - database DDL',
         EXPIRY_DATE = '20361231';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'DBAOps_SecurityCert')
BEGIN
    CREATE CERTIFICATE [DBAOps_SecurityCert]
    WITH SUBJECT = N'DBA_Operations v3 - database security',
         EXPIRY_DATE = '20361231';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'DBAOps_BackupCert')
BEGIN
    CREATE CERTIFICATE [DBAOps_BackupCert]
    WITH SUBJECT = N'DBA_Operations v3 - database backup',
         EXPIRY_DATE = '20361231';
END;
GO

/* ============================================================================
   4. EKSPORT PUBLICZNYCH CERTYFIKATÓW
   Katalog musi być dostępny dla konta usługi SQL Server.
   ============================================================================ */
BACKUP CERTIFICATE [DBAOps_DdlCert]
TO FILE = 'C:\Temp\DBAOps_DdlCert.cer';
GO

BACKUP CERTIFICATE [DBAOps_SecurityCert]
TO FILE = 'C:\Temp\DBAOps_SecurityCert.cer';
GO

BACKUP CERTIFICATE [DBAOps_BackupCert]
TO FILE = 'C:\Temp\DBAOps_BackupCert.cer';
GO

/* ============================================================================
   5. KONFIGURACJA
   ============================================================================ */
IF OBJECT_ID(N'dbo.Settings', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Settings
    (
        SettingName  sysname NOT NULL
            CONSTRAINT PK_DBAOps_Settings PRIMARY KEY,
        SettingValue nvarchar(4000) NOT NULL,
        ModifiedAt   datetime2(0) NOT NULL
            CONSTRAINT DF_DBAOps_Settings_ModifiedAt DEFAULT sysdatetime(),
        ModifiedBy   sysname NOT NULL
            CONSTRAINT DF_DBAOps_Settings_ModifiedBy DEFAULT original_login()
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Settings WHERE SettingName = N'BackupRoot')
BEGIN
    INSERT dbo.Settings(SettingName, SettingValue)
    VALUES(N'BackupRoot', N'D:\SQLBackups\Developer\');
END;
GO

IF OBJECT_ID(N'dbo.ManagedDatabase', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ManagedDatabase
    (
        DatabaseName  sysname NOT NULL
            CONSTRAINT PK_DBAOps_ManagedDatabase PRIMARY KEY,
        AllowDdl      bit NOT NULL
            CONSTRAINT DF_DBAOps_ManagedDatabase_AllowDdl DEFAULT(1),
        AllowSecurity bit NOT NULL
            CONSTRAINT DF_DBAOps_ManagedDatabase_AllowSecurity DEFAULT(0),
        AllowBackup   bit NOT NULL
            CONSTRAINT DF_DBAOps_ManagedDatabase_AllowBackup DEFAULT(0),
        IsEnabled     bit NOT NULL
            CONSTRAINT DF_DBAOps_ManagedDatabase_IsEnabled DEFAULT(1),
        Comment       nvarchar(400) NULL,
        CreatedAt     datetime2(0) NOT NULL
            CONSTRAINT DF_DBAOps_ManagedDatabase_CreatedAt DEFAULT sysdatetime(),
        CreatedBy     sysname NOT NULL
            CONSTRAINT DF_DBAOps_ManagedDatabase_CreatedBy DEFAULT original_login()
    );
END;
GO

IF OBJECT_ID(N'dbo.AllowedDatabaseRole', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AllowedDatabaseRole
    (
        RoleName  sysname NOT NULL
            CONSTRAINT PK_DBAOps_AllowedDatabaseRole PRIMARY KEY,
        IsEnabled bit NOT NULL
            CONSTRAINT DF_DBAOps_AllowedDatabaseRole_IsEnabled DEFAULT(1),
        Comment   nvarchar(400) NULL
    );
END;
GO

/*
    UWAGA:
      db_executor NIE jest dodawany do AllowedDatabaseRole.
      SQLLAB\Developer otrzymuje db_executor wyłącznie podczas onboardingu bazy
      wykonywanego przez DBA. Developer nie może sam przyznawać tej roli innym.
*/
MERGE dbo.AllowedDatabaseRole AS T
USING
(
    VALUES
      (N'db_datareader', N'Dozwolona rola odczytu danych'),
      (N'db_datawriter', N'Dozwolona rola zapisu danych')
) AS S(RoleName, Comment)
ON T.RoleName = S.RoleName
WHEN NOT MATCHED THEN
    INSERT(RoleName, IsEnabled, Comment)
    VALUES(S.RoleName, 1, S.Comment);
GO

/* ============================================================================
   6. AUDYT
   ============================================================================ */
IF OBJECT_ID(N'dbo.OperationAudit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.OperationAudit
    (
        AuditId       bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_DBAOps_OperationAudit PRIMARY KEY,
        EventTime     datetime2(0) NOT NULL
            CONSTRAINT DF_DBAOps_OperationAudit_EventTime DEFAULT sysdatetime(),
        OriginalLogin sysname NOT NULL,
        SessionLogin  sysname NOT NULL,
        OperationName nvarchar(100) NOT NULL,
        DatabaseName  sysname NULL,
        ObjectName    nvarchar(776) NULL,
        Details       nvarchar(4000) NULL,
        Succeeded     bit NOT NULL,
        ErrorNumber   int NULL,
        ErrorMessage  nvarchar(4000) NULL,
        HostName      nvarchar(128) NULL,
        AppName       nvarchar(128) NULL
    );
END;
GO

/* ============================================================================
   7. ROLE W DBA_Operations
   ============================================================================ */
IF DATABASE_PRINCIPAL_ID(N'DBA_DeveloperDdlOperator') IS NULL
    CREATE ROLE [DBA_DeveloperDdlOperator] AUTHORIZATION [dbo];
GO

IF DATABASE_PRINCIPAL_ID(N'DBA_DeveloperSecurityOperator') IS NULL
    CREATE ROLE [DBA_DeveloperSecurityOperator] AUTHORIZATION [dbo];
GO

IF DATABASE_PRINCIPAL_ID(N'DBA_DeveloperBackupOperator') IS NULL
    CREATE ROLE [DBA_DeveloperBackupOperator] AUTHORIZATION [dbo];
GO

IF DATABASE_PRINCIPAL_ID(N'DBA_OperationsAuditReader') IS NULL
    CREATE ROLE [DBA_OperationsAuditReader] AUTHORIZATION [dbo];
GO

/* ============================================================================
   8. HELPER - autoryzacja bazy
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_AssertManagedDatabase
    @DatabaseName sysname,
    @Capability varchar(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF DB_ID(@DatabaseName) IS NULL
        THROW 70001, N'Baza danych nie istnieje.', 1;

    IF @DatabaseName IN(N'master',N'model',N'msdb',N'tempdb',N'DBA_Operations')
        THROW 70002, N'Operacja na tej bazie jest zablokowana.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ManagedDatabase
        WHERE DatabaseName = @DatabaseName
          AND IsEnabled = 1
          AND
          (
              (@Capability = 'DDL'      AND AllowDdl = 1)
           OR (@Capability = 'SECURITY' AND AllowSecurity = 1)
           OR (@Capability = 'BACKUP'   AND AllowBackup = 1)
          )
    )
        THROW 70003, N'Baza nie jest włączona dla wymaganej funkcjonalności.', 1;
END;
GO

/* ============================================================================
   9. DDL - CREATE TABLE (kolumny w JSON)
   Przykład JSON:
   [
     {"name":"Id","type":"int","nullable":false,"identity":true},
     {"name":"Name","type":"nvarchar","length":200,"nullable":true}
   ]
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_CreateTable
    @DatabaseName sysname,
    @SchemaName   sysname = N'dbo',
    @TableName    sysname,
    @ColumnsJson  nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Sql nvarchar(max),
            @Columns nvarchar(max);

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'DDL';

        IF ISJSON(@ColumnsJson) <> 1
            THROW 70101, N'@ColumnsJson nie jest poprawnym JSON.', 1;

        DECLARE @C TABLE
        (
            Ordinal int,
            ColumnName sysname,
            TypeName sysname,
            LengthValue int NULL,
            PrecisionValue int NULL,
            ScaleValue int NULL,
            IsNullable bit,
            IsIdentity bit
        );

        INSERT @C
        (
            Ordinal, ColumnName, TypeName, LengthValue,
            PrecisionValue, ScaleValue, IsNullable, IsIdentity
        )
        SELECT
            CONVERT(int, [key]),
            JSON_VALUE(value,'$.name'),
            LOWER(JSON_VALUE(value,'$.type')),
            TRY_CONVERT(int,JSON_VALUE(value,'$.length')),
            TRY_CONVERT(int,JSON_VALUE(value,'$.precision')),
            TRY_CONVERT(int,JSON_VALUE(value,'$.scale')),
            COALESCE(TRY_CONVERT(bit,JSON_VALUE(value,'$.nullable')),1),
            COALESCE(TRY_CONVERT(bit,JSON_VALUE(value,'$.identity')),0)
        FROM OPENJSON(@ColumnsJson);

        IF NOT EXISTS(SELECT 1 FROM @C)
            THROW 70102, N'Lista kolumn jest pusta.', 1;

        IF EXISTS
        (
            SELECT 1 FROM @C
            WHERE NULLIF(ColumnName,N'') IS NULL
               OR TypeName NOT IN
               (
                   N'bigint',N'int',N'smallint',N'tinyint',N'bit',
                   N'decimal',N'numeric',N'money',N'smallmoney',
                   N'float',N'real',
                   N'date',N'datetime',N'datetime2',N'smalldatetime',N'time',
                   N'uniqueidentifier',
                   N'char',N'varchar',N'nchar',N'nvarchar',
                   N'binary',N'varbinary'
               )
        )
            THROW 70103, N'Niedozwolona nazwa kolumny lub typ danych.', 1;

        IF (SELECT COUNT(*) FROM @C WHERE IsIdentity = 1) > 1
            THROW 70104, N'Dozwolona jest maksymalnie jedna kolumna IDENTITY.', 1;

        IF EXISTS
        (
            SELECT 1 FROM @C
            WHERE IsIdentity = 1
              AND TypeName NOT IN(N'bigint',N'int',N'smallint',N'tinyint',N'decimal',N'numeric')
        )
            THROW 70105, N'IDENTITY użyto z niedozwolonym typem danych.', 1;

        SELECT @Columns =
            STUFF
            (
                (
                    SELECT
                        N', ' + QUOTENAME(ColumnName) + N' ' +
                        CASE
                            WHEN TypeName IN(N'char',N'varchar',N'nchar',N'nvarchar',N'binary',N'varbinary')
                                THEN TypeName + N'(' +
                                     CASE WHEN LengthValue = -1 AND TypeName IN(N'varchar',N'nvarchar',N'varbinary')
                                          THEN N'MAX'
                                          ELSE CONVERT(nvarchar(20),LengthValue)
                                     END + N')'
                            WHEN TypeName IN(N'decimal',N'numeric')
                                THEN TypeName + N'(' +
                                     CONVERT(nvarchar(20),COALESCE(PrecisionValue,18)) + N',' +
                                     CONVERT(nvarchar(20),COALESCE(ScaleValue,0)) + N')'
                            ELSE TypeName
                        END +
                        CASE WHEN IsIdentity = 1 THEN N' IDENTITY(1,1)' ELSE N'' END +
                        CASE WHEN IsNullable = 1 THEN N' NULL' ELSE N' NOT NULL' END
                    FROM @C
                    ORDER BY Ordinal
                    FOR XML PATH(''), TYPE
                ).value('.','nvarchar(max)'),
                1,2,N''
            );

        IF EXISTS
        (
            SELECT 1 FROM @C
            WHERE TypeName IN(N'char',N'varchar',N'nchar',N'nvarchar',N'binary',N'varbinary')
              AND
              (
                  LengthValue IS NULL
                  OR LengthValue = 0
                  OR LengthValue < -1
                  OR (LengthValue = -1 AND TypeName NOT IN(N'varchar',N'nvarchar',N'varbinary'))
              )
        )
            THROW 70106, N'Niepoprawna długość typu znakowego/binarnego.', 1;

        SET @Sql =
            N'USE ' + QUOTENAME(@DatabaseName) + N';
              IF SCHEMA_ID(N''' + REPLACE(@SchemaName,N'''',N'''''') + N''') IS NULL
                  THROW 70107, N''Schemat nie istnieje.'', 1;
              IF OBJECT_ID(N''' + REPLACE(@SchemaName + N'.' + @TableName,N'''',N'''''') + N''',N''U'') IS NOT NULL
                  THROW 70108, N''Tabela już istnieje.'', 1;
              CREATE TABLE ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) +
              N' (' + @Columns + N');';

        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Details,Succeeded,HostName,AppName)
        VALUES
        (ORIGINAL_LOGIN(),SUSER_SNAME(),N'CREATE TABLE',@DatabaseName,
         @SchemaName+N'.'+@TableName,@ColumnsJson,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Details,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES
        (ORIGINAL_LOGIN(),SUSER_SNAME(),N'CREATE TABLE',@DatabaseName,
         @SchemaName+N'.'+@TableName,@ColumnsJson,0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   10. DDL - DROP TABLE
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_DropTable
    @DatabaseName sysname,
    @SchemaName sysname = N'dbo',
    @TableName sysname
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql nvarchar(max);

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'DDL';

        SET @Sql =
            N'USE ' + QUOTENAME(@DatabaseName) + N';
              IF OBJECT_ID(N''' + REPLACE(@SchemaName+N'.'+@TableName,N'''',N'''''') + N''',N''U'') IS NULL
                  THROW 70201,N''Tabela nie istnieje.'',1;
              DROP TABLE ' + QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+N';';

        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'DROP TABLE',@DatabaseName,
               @SchemaName+N'.'+@TableName,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'DROP TABLE',@DatabaseName,
               @SchemaName+N'.'+@TableName,0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   11. DDL - ADD COLUMN
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_AddColumn
    @DatabaseName sysname,
    @SchemaName sysname = N'dbo',
    @TableName sysname,
    @ColumnName sysname,
    @DataType sysname,
    @Length int = NULL,
    @Precision tinyint = NULL,
    @Scale tinyint = NULL,
    @Nullable bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql nvarchar(max), @TypeSql nvarchar(100);
    SET @DataType = LOWER(@DataType);

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'DDL';

        IF @DataType NOT IN
        (
            N'bigint',N'int',N'smallint',N'tinyint',N'bit',
            N'decimal',N'numeric',N'money',N'smallmoney',N'float',N'real',
            N'date',N'datetime',N'datetime2',N'smalldatetime',N'time',
            N'uniqueidentifier',N'char',N'varchar',N'nchar',N'nvarchar',
            N'binary',N'varbinary'
        )
            THROW 70301,N'Niedozwolony typ danych.',1;

        SET @TypeSql =
            CASE
              WHEN @DataType IN(N'char',N'varchar',N'nchar',N'nvarchar',N'binary',N'varbinary')
                THEN @DataType + N'(' +
                     CASE WHEN @Length=-1 AND @DataType IN(N'varchar',N'nvarchar',N'varbinary')
                          THEN N'MAX'
                          ELSE CONVERT(nvarchar(10),@Length) END + N')'
              WHEN @DataType IN(N'decimal',N'numeric')
                THEN @DataType + N'(' +
                     CONVERT(nvarchar(10),COALESCE(@Precision,18)) + N',' +
                     CONVERT(nvarchar(10),COALESCE(@Scale,0)) + N')'
              ELSE @DataType
            END;

        IF @TypeSql IS NULL OR @TypeSql LIKE N'%(NULL)%'
            THROW 70302,N'Brak wymaganej długości/parametru typu.',1;

        SET @Sql =
            N'USE ' + QUOTENAME(@DatabaseName) + N';
              IF OBJECT_ID(N''' + REPLACE(@SchemaName+N'.'+@TableName,N'''',N'''''') + N''',N''U'') IS NULL
                  THROW 70303,N''Tabela nie istnieje.'',1;
              IF COL_LENGTH(N''' + REPLACE(@SchemaName+N'.'+@TableName,N'''',N'''''') +
              N''',N''' + REPLACE(@ColumnName,N'''',N'''''') + N''') IS NOT NULL
                  THROW 70304,N''Kolumna już istnieje.'',1;
              ALTER TABLE ' + QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName) +
              N' ADD ' + QUOTENAME(@ColumnName)+N' '+@TypeSql+
              CASE WHEN @Nullable=1 THEN N' NULL;' ELSE N' NOT NULL;' END;

        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Details,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'ADD COLUMN',@DatabaseName,
               @SchemaName+N'.'+@TableName+N'.'+@ColumnName,@TypeSql,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'ADD COLUMN',@DatabaseName,
               @SchemaName+N'.'+@TableName+N'.'+@ColumnName,0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   12. DDL - DROP COLUMN
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_DropColumn
    @DatabaseName sysname,
    @SchemaName sysname = N'dbo',
    @TableName sysname,
    @ColumnName sysname
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql nvarchar(max);

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'DDL';

        SET @Sql =
            N'USE ' + QUOTENAME(@DatabaseName) + N';
              IF COL_LENGTH(N''' + REPLACE(@SchemaName+N'.'+@TableName,N'''',N'''''') +
              N''',N''' + REPLACE(@ColumnName,N'''',N'''''') + N''') IS NULL
                  THROW 70401,N''Kolumna nie istnieje.'',1;
              ALTER TABLE ' + QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@TableName)+
              N' DROP COLUMN '+QUOTENAME(@ColumnName)+N';';

        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'DROP COLUMN',@DatabaseName,
               @SchemaName+N'.'+@TableName+N'.'+@ColumnName,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'DROP COLUMN',@DatabaseName,
               @SchemaName+N'.'+@TableName+N'.'+@ColumnName,0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   13. DDL - CREATE OR ALTER VIEW
   @SelectBody musi być pojedynczym SELECT/WITH, bez średnika i komentarzy.
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_CreateOrAlterView
    @DatabaseName sysname,
    @SchemaName sysname = N'dbo',
    @ViewName sysname,
    @SelectBody nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql nvarchar(max), @Trim nvarchar(max)=LTRIM(@SelectBody);

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'DDL';

        IF UPPER(LEFT(@Trim,6)) <> N'SELECT'
           AND UPPER(LEFT(@Trim,4)) <> N'WITH'
            THROW 70501,N'Widok musi zaczynać się od SELECT lub WITH.',1;

        IF @SelectBody LIKE N'%;%'
           OR @SelectBody LIKE N'%--%'
           OR @SelectBody LIKE N'%/*%'
           OR @SelectBody LIKE N'%*/%'
            THROW 70502,N'Definicja widoku zawiera niedozwolone tokeny.',1;

        SET @Sql =
            N'USE '+QUOTENAME(@DatabaseName)+N';
              CREATE OR ALTER VIEW '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@ViewName)+
              N' AS '+@SelectBody+N';';

        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'CREATE OR ALTER VIEW',@DatabaseName,
               @SchemaName+N'.'+@ViewName,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'CREATE OR ALTER VIEW',@DatabaseName,
               @SchemaName+N'.'+@ViewName,0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   14. DDL - DROP VIEW
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_DropView
    @DatabaseName sysname,
    @SchemaName sysname = N'dbo',
    @ViewName sysname
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql nvarchar(max);

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'DDL';

        SET @Sql=N'USE '+QUOTENAME(@DatabaseName)+N';
                   IF OBJECT_ID(N'''+REPLACE(@SchemaName+N'.'+@ViewName,N'''',N'''''')+N''',N''V'') IS NULL
                     THROW 70601,N''Widok nie istnieje.'',1;
                   DROP VIEW '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@ViewName)+N';';
        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'DROP VIEW',@DatabaseName,
               @SchemaName+N'.'+@ViewName,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'DROP VIEW',@DatabaseName,
               @SchemaName+N'.'+@ViewName,0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   15. DDL - CREATE OR ALTER PROCEDURE
   Parametry w JSON, np.
   [{"name":"@Id","type":"int","output":false},
    {"name":"@Name","type":"nvarchar","length":100,"output":false}]

   Body jest kodem procedury, ale wrapper NIE pozwala ustawić EXECUTE AS
   ani dołączyć nagłówka/properties procedury.
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_CreateOrAlterProcedure
    @DatabaseName sysname,
    @SchemaName sysname = N'dbo',
    @ProcedureName sysname,
    @ParametersJson nvarchar(max) = N'[]',
    @Body nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql nvarchar(max), @Params nvarchar(max)=N'';

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'DDL';

        IF ISJSON(@ParametersJson) <> 1
            THROW 70701,N'@ParametersJson nie jest poprawnym JSON.',1;

        IF UPPER(@Body) LIKE N'%EXECUTE AS%'
            THROW 70702,N'EXECUTE AS w body procedury jest zablokowane.',1;

        DECLARE @P TABLE
        (
            Ordinal int,
            ParamName sysname,
            TypeName sysname,
            LengthValue int NULL,
            PrecisionValue int NULL,
            ScaleValue int NULL,
            IsOutput bit
        );

        INSERT @P
        SELECT CONVERT(int,[key]),
               JSON_VALUE(value,'$.name'),
               LOWER(JSON_VALUE(value,'$.type')),
               TRY_CONVERT(int,JSON_VALUE(value,'$.length')),
               TRY_CONVERT(int,JSON_VALUE(value,'$.precision')),
               TRY_CONVERT(int,JSON_VALUE(value,'$.scale')),
               COALESCE(TRY_CONVERT(bit,JSON_VALUE(value,'$.output')),0)
        FROM OPENJSON(@ParametersJson);

        IF EXISTS
        (
            SELECT 1 FROM @P
            WHERE LEFT(ParamName,1) <> N'@'
               OR TypeName NOT IN
               (
                   N'bigint',N'int',N'smallint',N'tinyint',N'bit',
                   N'decimal',N'numeric',N'money',N'smallmoney',N'float',N'real',
                   N'date',N'datetime',N'datetime2',N'smalldatetime',N'time',
                   N'uniqueidentifier',N'char',N'varchar',N'nchar',N'nvarchar',
                   N'binary',N'varbinary'
               )
        )
            THROW 70703,N'Niepoprawny parametr procedury.',1;

        SELECT @Params =
            STUFF
            (
                (
                    SELECT N', '+ParamName+N' '+
                        CASE
                          WHEN TypeName IN(N'char',N'varchar',N'nchar',N'nvarchar',N'binary',N'varbinary')
                            THEN TypeName+N'('+CASE WHEN LengthValue=-1 AND TypeName IN(N'varchar',N'nvarchar',N'varbinary')
                                                   THEN N'MAX' ELSE CONVERT(nvarchar(10),LengthValue) END+N')'
                          WHEN TypeName IN(N'decimal',N'numeric')
                            THEN TypeName+N'('+CONVERT(nvarchar(10),COALESCE(PrecisionValue,18))+N','+
                                               CONVERT(nvarchar(10),COALESCE(ScaleValue,0))+N')'
                          ELSE TypeName
                        END+
                        CASE WHEN IsOutput=1 THEN N' OUTPUT' ELSE N'' END
                    FROM @P
                    ORDER BY Ordinal
                    FOR XML PATH(''),TYPE
                ).value('.','nvarchar(max)'),1,2,N''
            );

        SET @Sql =
            N'USE '+QUOTENAME(@DatabaseName)+N';
              CREATE OR ALTER PROCEDURE '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@ProcedureName)+
              CASE WHEN NULLIF(@Params,N'') IS NULL THEN N'' ELSE N' '+@Params END+
              N' AS
              BEGIN
                  SET NOCOUNT ON;
                  '+@Body+N'
              END;';

        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'CREATE OR ALTER PROCEDURE',@DatabaseName,
               @SchemaName+N'.'+@ProcedureName,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'CREATE OR ALTER PROCEDURE',@DatabaseName,
               @SchemaName+N'.'+@ProcedureName,0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   16. DDL - DROP PROCEDURE
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_DropProcedure
    @DatabaseName sysname,
    @SchemaName sysname = N'dbo',
    @ProcedureName sysname
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql nvarchar(max);

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'DDL';

        SET @Sql=N'USE '+QUOTENAME(@DatabaseName)+N';
                   IF OBJECT_ID(N'''+REPLACE(@SchemaName+N'.'+@ProcedureName,N'''',N'''''')+N''',N''P'') IS NULL
                     THROW 70801,N''Procedura nie istnieje.'',1;
                   DROP PROCEDURE '+QUOTENAME(@SchemaName)+N'.'+QUOTENAME(@ProcedureName)+N';';
        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'DROP PROCEDURE',@DatabaseName,
               @SchemaName+N'.'+@ProcedureName,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'DROP PROCEDURE',@DatabaseName,
               @SchemaName+N'.'+@ProcedureName,0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   17. DATABASE SECURITY - CREATE USER
   Login musi już istnieć na poziomie instancji.
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_CreateDatabaseUser
    @DatabaseName sysname,
    @LoginName sysname,
    @UserName sysname = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql nvarchar(max),
            @EffectiveUserName sysname=COALESCE(NULLIF(@UserName,N''),@LoginName);

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'SECURITY';

        IF SUSER_ID(@LoginName) IS NULL
            THROW 71001,N'Login serwerowy nie istnieje. Login tworzy administrator.',1;

        SET @Sql=
            N'USE '+QUOTENAME(@DatabaseName)+N';
              IF DATABASE_PRINCIPAL_ID(N'''+REPLACE(@EffectiveUserName,N'''',N'''''')+N''') IS NOT NULL
                THROW 71002,N''Użytkownik już istnieje w bazie.'',1;
              CREATE USER '+QUOTENAME(@EffectiveUserName)+N' FOR LOGIN '+QUOTENAME(@LoginName)+N';';

        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'CREATE DATABASE USER',@DatabaseName,
               @EffectiveUserName+N' <- '+@LoginName,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'CREATE DATABASE USER',@DatabaseName,
               COALESCE(@EffectiveUserName,@LoginName),0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   18. DATABASE SECURITY - DROP USER
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_DropDatabaseUser
    @DatabaseName sysname,
    @UserName sysname
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql nvarchar(max);

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'SECURITY';

        IF @UserName IN(N'dbo',N'guest',N'INFORMATION_SCHEMA',N'sys')
            THROW 71101,N'Ten użytkownik jest chroniony.',1;

        SET @Sql=
            N'USE '+QUOTENAME(@DatabaseName)+N';
              IF DATABASE_PRINCIPAL_ID(N'''+REPLACE(@UserName,N'''',N'''''')+N''') IS NULL
                THROW 71102,N''Użytkownik nie istnieje.'',1;
              DROP USER '+QUOTENAME(@UserName)+N';';

        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'DROP DATABASE USER',@DatabaseName,
               @UserName,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'DROP DATABASE USER',@DatabaseName,
               @UserName,0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   19. DATABASE SECURITY - ADD USER TO APPROVED ROLE
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_AddUserToDatabaseRole
    @DatabaseName sysname,
    @UserName sysname,
    @RoleName sysname
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql nvarchar(max);

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'SECURITY';

        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.AllowedDatabaseRole
            WHERE RoleName=@RoleName AND IsEnabled=1
        )
            THROW 71201,N'Rola nie znajduje się na liście dozwolonych ról.',1;

        SET @Sql=
            N'USE '+QUOTENAME(@DatabaseName)+N';
              IF DATABASE_PRINCIPAL_ID(N'''+REPLACE(@UserName,N'''',N'''''')+N''') IS NULL
                THROW 71202,N''Użytkownik nie istnieje.'',1;
              IF NOT EXISTS
              (
                  SELECT 1
                  FROM sys.database_role_members drm
                  JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
                  JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
                  WHERE r.name=N'''+REPLACE(@RoleName,N'''',N'''''')+N'''
                    AND m.name=N'''+REPLACE(@UserName,N'''',N'''''')+N'''
              )
                  ALTER ROLE '+QUOTENAME(@RoleName)+N' ADD MEMBER '+QUOTENAME(@UserName)+N';';

        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'ADD USER TO DATABASE ROLE',@DatabaseName,
               @UserName+N' -> '+@RoleName,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'ADD USER TO DATABASE ROLE',@DatabaseName,
               @UserName+N' -> '+@RoleName,0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   20. DATABASE SECURITY - REMOVE USER FROM APPROVED ROLE
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_RemoveUserFromDatabaseRole
    @DatabaseName sysname,
    @UserName sysname,
    @RoleName sysname
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql nvarchar(max);

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'SECURITY';

        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.AllowedDatabaseRole
            WHERE RoleName=@RoleName AND IsEnabled=1
        )
            THROW 71301,N'Rola nie znajduje się na liście dozwolonych ról.',1;

        SET @Sql=
            N'USE '+QUOTENAME(@DatabaseName)+N';
              IF EXISTS
              (
                  SELECT 1
                  FROM sys.database_role_members drm
                  JOIN sys.database_principals r ON r.principal_id=drm.role_principal_id
                  JOIN sys.database_principals m ON m.principal_id=drm.member_principal_id
                  WHERE r.name=N'''+REPLACE(@RoleName,N'''',N'''''')+N'''
                    AND m.name=N'''+REPLACE(@UserName,N'''',N'''''')+N'''
              )
                  ALTER ROLE '+QUOTENAME(@RoleName)+N' DROP MEMBER '+QUOTENAME(@UserName)+N';';

        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'REMOVE USER FROM DATABASE ROLE',@DatabaseName,
               @UserName+N' <- '+@RoleName,1,HOST_NAME(),APP_NAME());
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,ObjectName,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'REMOVE USER FROM DATABASE ROLE',@DatabaseName,
               @UserName+N' <- '+@RoleName,0,ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   21. BACKUP - tylko zarządzane bazy z AllowBackup=1
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_BackupDatabase
    @DatabaseName sysname
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Root nvarchar(4000),@File nvarchar(4000),@Sql nvarchar(max),@Safe sysname;

    BEGIN TRY
        EXEC ops.usp_AssertManagedDatabase @DatabaseName, 'BACKUP';

        SELECT @Root=SettingValue
        FROM dbo.Settings
        WHERE SettingName=N'BackupRoot';

        IF RIGHT(@Root,1)<>N'\' SET @Root+=N'\';

        SET @Safe=REPLACE(REPLACE(@DatabaseName,N'\',N'_'),N'/',N'_');
        SET @File=@Root+@Safe+N'_'+CONVERT(char(8),GETDATE(),112)+N'_'
                 +REPLACE(CONVERT(char(8),GETDATE(),108),N':',N'')+N'.bak';

        SET @Sql=N'BACKUP DATABASE '+QUOTENAME(@DatabaseName)+
                 N' TO DISK=N'''+REPLACE(@File,N'''',N'''''')+
                 N''' WITH COPY_ONLY,CHECKSUM,COMPRESSION,INIT,STATS=10;';

        EXEC sys.sp_executesql @Sql;

        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,Details,Succeeded,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'BACKUP DATABASE',@DatabaseName,@File,1,HOST_NAME(),APP_NAME());

        SELECT @File AS BackupFile;
    END TRY
    BEGIN CATCH
        INSERT dbo.OperationAudit
        (OriginalLogin,SessionLogin,OperationName,DatabaseName,Details,Succeeded,ErrorNumber,ErrorMessage,HostName,AppName)
        VALUES(ORIGINAL_LOGIN(),SUSER_SNAME(),N'BACKUP DATABASE',@DatabaseName,@File,0,
               ERROR_NUMBER(),ERROR_MESSAGE(),HOST_NAME(),APP_NAME());
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   22. AUDYT
   ============================================================================ */
CREATE OR ALTER PROCEDURE ops.usp_MyOperationAudit
    @Top int=100
AS
BEGIN
    SET NOCOUNT ON;
    IF @Top<1 SET @Top=1;
    IF @Top>1000 SET @Top=1000;

    SELECT TOP(@Top)
        AuditId,EventTime,OperationName,DatabaseName,ObjectName,Details,
        Succeeded,ErrorNumber,ErrorMessage,HostName,AppName
    FROM dbo.OperationAudit
    WHERE OriginalLogin=ORIGINAL_LOGIN()
    ORDER BY AuditId DESC;
END;
GO

CREATE OR ALTER PROCEDURE ops.usp_AllOperationAudit
    @Top int=500
AS
BEGIN
    SET NOCOUNT ON;
    IF @Top<1 SET @Top=1;
    IF @Top>5000 SET @Top=5000;

    SELECT TOP(@Top) *
    FROM dbo.OperationAudit
    ORDER BY AuditId DESC;
END;
GO

/* ============================================================================
   23. GRANT EXECUTE DO FUNKCJONALNYCH RÓL
   ============================================================================ */
GRANT EXECUTE ON OBJECT::ops.usp_CreateTable               TO [DBA_DeveloperDdlOperator];
GRANT EXECUTE ON OBJECT::ops.usp_DropTable                 TO [DBA_DeveloperDdlOperator];
GRANT EXECUTE ON OBJECT::ops.usp_AddColumn                 TO [DBA_DeveloperDdlOperator];
GRANT EXECUTE ON OBJECT::ops.usp_DropColumn                TO [DBA_DeveloperDdlOperator];
GRANT EXECUTE ON OBJECT::ops.usp_CreateOrAlterView         TO [DBA_DeveloperDdlOperator];
GRANT EXECUTE ON OBJECT::ops.usp_DropView                  TO [DBA_DeveloperDdlOperator];
GRANT EXECUTE ON OBJECT::ops.usp_CreateOrAlterProcedure    TO [DBA_DeveloperDdlOperator];
GRANT EXECUTE ON OBJECT::ops.usp_DropProcedure             TO [DBA_DeveloperDdlOperator];

GRANT EXECUTE ON OBJECT::ops.usp_CreateDatabaseUser        TO [DBA_DeveloperSecurityOperator];
GRANT EXECUTE ON OBJECT::ops.usp_DropDatabaseUser          TO [DBA_DeveloperSecurityOperator];
GRANT EXECUTE ON OBJECT::ops.usp_AddUserToDatabaseRole     TO [DBA_DeveloperSecurityOperator];
GRANT EXECUTE ON OBJECT::ops.usp_RemoveUserFromDatabaseRole TO [DBA_DeveloperSecurityOperator];

GRANT EXECUTE ON OBJECT::ops.usp_BackupDatabase            TO [DBA_DeveloperBackupOperator];

GRANT EXECUTE ON OBJECT::ops.usp_MyOperationAudit
TO [DBA_DeveloperDdlOperator],
   [DBA_DeveloperSecurityOperator],
   [DBA_DeveloperBackupOperator];

GRANT EXECUTE ON OBJECT::ops.usp_AllOperationAudit
TO [DBA_OperationsAuditReader];
GO

/* ============================================================================
   24. PODPISYWANIE MODUŁÓW - DDL
   ============================================================================ */
ADD SIGNATURE TO OBJECT::ops.usp_CreateTable
BY CERTIFICATE [DBAOps_DdlCert];
GO
ADD SIGNATURE TO OBJECT::ops.usp_DropTable
BY CERTIFICATE [DBAOps_DdlCert];
GO
ADD SIGNATURE TO OBJECT::ops.usp_AddColumn
BY CERTIFICATE [DBAOps_DdlCert];
GO
ADD SIGNATURE TO OBJECT::ops.usp_DropColumn
BY CERTIFICATE [DBAOps_DdlCert];
GO
ADD SIGNATURE TO OBJECT::ops.usp_CreateOrAlterView
BY CERTIFICATE [DBAOps_DdlCert];
GO
ADD SIGNATURE TO OBJECT::ops.usp_DropView
BY CERTIFICATE [DBAOps_DdlCert];
GO
ADD SIGNATURE TO OBJECT::ops.usp_CreateOrAlterProcedure
BY CERTIFICATE [DBAOps_DdlCert];
GO
ADD SIGNATURE TO OBJECT::ops.usp_DropProcedure
BY CERTIFICATE [DBAOps_DdlCert];
GO

/* ============================================================================
   25. PODPISYWANIE MODUŁÓW - DATABASE SECURITY
   ============================================================================ */
ADD SIGNATURE TO OBJECT::ops.usp_CreateDatabaseUser
BY CERTIFICATE [DBAOps_SecurityCert];
GO
ADD SIGNATURE TO OBJECT::ops.usp_DropDatabaseUser
BY CERTIFICATE [DBAOps_SecurityCert];
GO
ADD SIGNATURE TO OBJECT::ops.usp_AddUserToDatabaseRole
BY CERTIFICATE [DBAOps_SecurityCert];
GO
ADD SIGNATURE TO OBJECT::ops.usp_RemoveUserFromDatabaseRole
BY CERTIFICATE [DBAOps_SecurityCert];
GO

/* ============================================================================
   26. PODPISYWANIE MODUŁÓW - BACKUP
   ============================================================================ */
ADD SIGNATURE TO OBJECT::ops.usp_BackupDatabase
BY CERTIFICATE [DBAOps_BackupCert];
GO

/* ============================================================================
   27. WERYFIKACJA PODPISÓW
   ============================================================================ */
SELECT
    s.name AS SchemaName,
    o.name AS ObjectName,
    c.name AS CertificateName
FROM sys.crypt_properties cp
JOIN sys.objects o
  ON o.object_id=cp.major_id
JOIN sys.schemas s
  ON s.schema_id=o.schema_id
JOIN sys.certificates c
  ON c.thumbprint=cp.thumbprint
WHERE cp.class=1
  AND s.name=N'ops'
ORDER BY o.name,c.name;
GO

/*
===============================================================================
KONIEC DEPLOYMENTU MECHANIZMU

Następnie uruchom:
    DBA_Operations_v3_Admin_Config_and_Developer_Usage.sql

Ten drugi skrypt:
  - tworzy login SQLLAB\Developer,
  - mapuje grupę do DBA_Operations,
  - mapuje grupę do baz,
  - instaluje publiczne certyfikaty w zarządzanych bazach,
  - przyznaje minimalne prawa certyfikatowym userom,
  - dodaje bazy do dbo.ManagedDatabase,
  - pokazuje przykłady użycia przez developera.
===============================================================================
*/
