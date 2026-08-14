/*==============================================================================
    DEMO
    Nie dawaj sysadmina. Zaprojektuj uprawnienia w SQL Server.

    Cel:
      1. Utworzyć login SQL bez sysadmin.
      2. Pozwolić mu tworzyć bazy.
      3. Nadać ograniczone uprawnienia diagnostyczne.
      4. Nadać dostęp do SQL Server Agent.
      5. Pokazać operacje DOZWOLONE.
      6. Pokazać operacje ZABRONIONE.
      7. Posprzątać środowisko.

    Wymagania:
      - uruchom skrypt jako sysadmin
      - SQL Server 2016+
      - do uruchomienia joba usługa SQL Server Agent musi działać

    UWAGA:
      Hasło poniżej jest wyłącznie demonstracyjne.
==============================================================================*/

USE [master];
GO

SET NOCOUNT ON;
GO


/*==============================================================================
    00. PARAMETRY DEMO
==============================================================================*/

DECLARE @LoginName sysname = N'SQLDeployDemo';

PRINT '===============================================================';
PRINT ' DEMO: Least privilege zamiast sysadmin';
PRINT '===============================================================';
PRINT '';


/*==============================================================================
    01. CLEANUP PO POPRZEDNIM DEMO
==============================================================================*/

PRINT '01. Cleanup poprzedniego środowiska';
GO


/*------------------------------------------------------------------------------
    Usuń testowy job, jeżeli istnieje
------------------------------------------------------------------------------*/

USE [msdb];
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.sysjobs
    WHERE name = N'DEMO - Least Privilege'
)
BEGIN
    EXEC dbo.sp_delete_job
        @job_name = N'DEMO - Least Privilege';

    PRINT 'Usunięto istniejący job.';
END;
GO


/*------------------------------------------------------------------------------
    Usuń użytkownika z msdb
------------------------------------------------------------------------------*/

IF EXISTS
(
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'SQLDeployDemo'
)
BEGIN
    DROP USER [SQLDeployDemo];

    PRINT 'Usunięto użytkownika SQLDeployDemo z msdb.';
END;
GO


/*------------------------------------------------------------------------------
    Usuń testową bazę
------------------------------------------------------------------------------*/

USE [master];
GO

IF DB_ID(N'DemoDeploymentDatabase') IS NOT NULL
BEGIN
    ALTER DATABASE [DemoDeploymentDatabase]
        SET SINGLE_USER
        WITH ROLLBACK IMMEDIATE;

    DROP DATABASE [DemoDeploymentDatabase];

    PRINT 'Usunięto DemoDeploymentDatabase.';
END;
GO


/*------------------------------------------------------------------------------
    Usuń login z customowej roli
------------------------------------------------------------------------------*/

IF EXISTS
(
    SELECT 1
    FROM sys.server_principals
    WHERE name = N'SQLDeployDemo'
)
AND EXISTS
(
    SELECT 1
    FROM sys.server_principals
    WHERE name = N'DeployOperators'
      AND type = 'R'
)
BEGIN

    IF IS_SRVROLEMEMBER
    (
        N'DeployOperators',
        N'SQLDeployDemo'
    ) = 1
    BEGIN

        ALTER SERVER ROLE [DeployOperators]
            DROP MEMBER [SQLDeployDemo];

    END;

END;
GO


/*------------------------------------------------------------------------------
    Usuń login z dbcreator
------------------------------------------------------------------------------*/

IF EXISTS
(
    SELECT 1
    FROM sys.server_principals
    WHERE name = N'SQLDeployDemo'
)
BEGIN

    IF IS_SRVROLEMEMBER
    (
        N'dbcreator',
        N'SQLDeployDemo'
    ) = 1
    BEGIN

        ALTER SERVER ROLE [dbcreator]
            DROP MEMBER [SQLDeployDemo];

    END;

END;
GO


/*------------------------------------------------------------------------------
    Usuń login
------------------------------------------------------------------------------*/

IF EXISTS
(
    SELECT 1
    FROM sys.server_principals
    WHERE name = N'SQLDeployDemo'
)
BEGIN

    DROP LOGIN [SQLDeployDemo];

    PRINT 'Usunięto login SQLDeployDemo.';

END;
GO


/*------------------------------------------------------------------------------
    Usuń customową rolę
------------------------------------------------------------------------------*/

IF EXISTS
(
    SELECT 1
    FROM sys.server_principals
    WHERE name = N'DeployOperators'
      AND type = 'R'
)
BEGIN

    DROP SERVER ROLE [DeployOperators];

    PRINT 'Usunięto rolę DeployOperators.';

END;
GO



/*==============================================================================
    02. TWORZYMY LOGIN
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '02. Tworzenie loginu';
PRINT '===============================================================';
GO


CREATE LOGIN [SQLDeployDemo]
WITH 
    PASSWORD = N'SQL-Demo-Only!2026',
    CHECK_POLICY = OFF,
    CHECK_EXPIRATION = OFF
;
GO


SELECT
    name,
    type_desc,
    is_disabled
FROM sys.server_principals
WHERE name = N'SQLDeployDemo';
GO



/*==============================================================================
    03. SPRAWDZENIE: LOGIN NIE JEST SYSADMINEM
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '03. Czy użytkownik jest sysadminem?';
PRINT '===============================================================';
GO


SELECT
    N'SQLDeployDemo' AS LoginName,
    IS_SRVROLEMEMBER
    (
        N'sysadmin',
        N'SQLDeployDemo'
    ) AS IsSysadmin;
GO


/*
    Oczekiwany wynik:

    IsSysadmin
    ----------
    0
*/



/*==============================================================================
    04. DB CREATOR
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '04. Nadajemy możliwość tworzenia baz';
PRINT '===============================================================';
GO


ALTER SERVER ROLE [dbcreator]
ADD MEMBER [SQLDeployDemo];
GO



/*==============================================================================
    05. CUSTOMOWA ROLA SERWEROWA
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '05. Customowa rola DeployOperators';
PRINT '===============================================================';
GO


CREATE SERVER ROLE [DeployOperators];
GO


/*
    Użytkownik może zobaczyć stan instancji.

    Na SQL Server 2022 można rozważyć bardziej granularne
    VIEW SERVER PERFORMANCE STATE.
*/

GRANT VIEW SERVER STATE
TO [DeployOperators];
GO


/*
    Pozwalamy widzieć wszystkie bazy.
*/

GRANT VIEW ANY DATABASE
TO [DeployOperators];
GO


/*
    Dodajemy login do naszej roli.
*/

ALTER SERVER ROLE [DeployOperators]
ADD MEMBER [SQLDeployDemo];
GO



/*==============================================================================
    06. POKAŻ CZŁONKOSTWO W ROLACH
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '06. Role serwerowe';
PRINT '===============================================================';
GO


SELECT
    MemberName = MemberPrincipal.name,
    ServerRole = RolePrincipal.name
FROM sys.server_role_members AS RoleMember
INNER JOIN sys.server_principals AS RolePrincipal
    ON RolePrincipal.principal_id =
       RoleMember.role_principal_id
INNER JOIN sys.server_principals AS MemberPrincipal
    ON MemberPrincipal.principal_id =
       RoleMember.member_principal_id
WHERE MemberPrincipal.name = N'SQLDeployDemo'
ORDER BY
    RolePrincipal.name;
GO


/*
    Powinniśmy zobaczyć:

    dbcreator
    DeployOperators

    NIE MA:

    sysadmin
*/



/*==============================================================================
    07. SQL SERVER AGENT
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '07. SQL Server Agent';
PRINT '===============================================================';
GO


USE [msdb];
GO


CREATE USER [SQLDeployDemo]
FOR LOGIN [SQLDeployDemo];
GO


/*
    SQLAgentOperatorRole jest najsilniejszą z trzech standardowych
    ról Agenta dla użytkowników niebędących sysadminami.

    SQLAgentUserRole
    SQLAgentReaderRole
    SQLAgentOperatorRole
*/

ALTER ROLE [SQLAgentOperatorRole]
ADD MEMBER [SQLDeployDemo];
GO



/*==============================================================================
    08. POKAŻ CZŁONKOSTWO W ROLACH MSDB
==============================================================================*/

SELECT
    UserName =
        DatabasePrincipal.name,

    RoleName =
        DatabaseRole.name

FROM sys.database_role_members AS RoleMember

INNER JOIN sys.database_principals AS DatabaseRole
    ON DatabaseRole.principal_id =
       RoleMember.role_principal_id

INNER JOIN sys.database_principals AS DatabasePrincipal
    ON DatabasePrincipal.principal_id =
       RoleMember.member_principal_id

WHERE DatabasePrincipal.name =
      N'SQLDeployDemo';
GO



/*==============================================================================
    09. TEST POZYTYWNY
    Czy użytkownik może utworzyć bazę?
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '09. TEST POZYTYWNY: CREATE DATABASE';
PRINT '===============================================================';
GO


USE [master];
GO


EXECUTE AS LOGIN = N'SQLDeployDemo';
GO


SELECT
    ORIGINAL_LOGIN() AS OriginalLogin,
    SUSER_SNAME()     AS CurrentLogin;
GO


CREATE DATABASE [DemoDeploymentDatabase];
GO


REVERT;
GO


PRINT 'OK - SQLDeployDemo utworzył bazę.';
GO



/*==============================================================================
    10. POTWIERDŹ UTWORZENIE BAZY
==============================================================================*/

SELECT
    name,
    state_desc,
    recovery_model_desc,
    create_date
FROM sys.databases
WHERE name = N'DemoDeploymentDatabase';
GO



/*==============================================================================
    11. EFEKTYWNE UPRAWNIENIA
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '11. Efektywne uprawnienia użytkownika';
PRINT '===============================================================';
GO


EXECUTE AS LOGIN = N'SQLDeployDemo';
GO


SELECT
    permission_name
FROM sys.fn_my_permissions
(
    NULL,
    N'SERVER'
)
ORDER BY
    permission_name;
GO


REVERT;
GO



/*==============================================================================
    12. TEST NEGATYWNY
    Czy użytkownik może zrobić siebie sysadminem?
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '12. TEST NEGATYWNY: próba nadania sysadmin';
PRINT '===============================================================';
GO


EXECUTE AS LOGIN = N'SQLDeployDemo';
GO


BEGIN TRY

    ALTER SERVER ROLE [sysadmin]
        ADD MEMBER [SQLDeployDemo];

    PRINT 'UWAGA!';
    PRINT 'Operacja nie powinna się udać.';

END TRY

BEGIN CATCH

    PRINT '';
    PRINT 'OCZEKIWANY BŁĄD:';
    PRINT ERROR_MESSAGE();

END CATCH;
GO


REVERT;
GO



/*==============================================================================
    13. POTWIERDŹ, ŻE SYSADMIN NADAL = 0
==============================================================================*/

SELECT
    N'SQLDeployDemo' AS LoginName,

    IS_SRVROLEMEMBER
    (
        N'sysadmin',
        N'SQLDeployDemo'
    ) AS IsSysadmin;
GO



/*==============================================================================
    14. TEST NEGATYWNY
    Próba zmiany konfiguracji serwera
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '14. TEST NEGATYWNY: sp_configure';
PRINT '===============================================================';
GO


EXECUTE AS LOGIN = N'SQLDeployDemo';
GO


BEGIN TRY

    EXEC sys.sp_configure
        N'show advanced options',
        1;

    RECONFIGURE;

    PRINT 'UWAGA!';
    PRINT 'Operacja nie powinna się udać.';

END TRY

BEGIN CATCH

    PRINT '';
    PRINT 'OCZEKIWANY BŁĄD:';
    PRINT ERROR_MESSAGE();

END CATCH;
GO


REVERT;
GO



/*==============================================================================
    15. TEST SQL SERVER AGENT

    Utworzymy prosty job należący do SQLDeployDemo.

    Nie potrzebujemy sysadmina.
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '15. SQL Server Agent - tworzenie własnego joba';
PRINT '===============================================================';
GO


USE [msdb];
GO


EXECUTE AS LOGIN = N'SQLDeployDemo';
GO


BEGIN TRY

    EXEC dbo.sp_add_job
        @job_name =
            N'DEMO - Least Privilege',

        @enabled = 1,

        @description =
            N'Job utworzony przez użytkownika bez sysadmin.';


    EXEC dbo.sp_add_jobstep
        @job_name =
            N'DEMO - Least Privilege',

        @step_name =
            N'Test T-SQL',

        @subsystem =
            N'TSQL',

        @database_name =
            N'master',

        @command =
            N'
            SELECT
                @@SERVERNAME AS ServerName,
                SUSER_SNAME() AS LoginName,
                SYSDATETIME() AS ExecutionTime;
            ';


    EXEC dbo.sp_add_jobserver
        @job_name =
            N'DEMO - Least Privilege';


    PRINT '';
    PRINT 'OK - Job został utworzony.';

END TRY

BEGIN CATCH

    PRINT '';
    PRINT 'BŁĄD SQL SERVER AGENT:';
    PRINT ERROR_MESSAGE();

END CATCH;
GO


REVERT;
GO



/*==============================================================================
    16. POKAŻ UTWORZONY JOB
==============================================================================*/

SELECT
    j.name AS JobName,

    SUSER_SNAME
    (
        j.owner_sid
    ) AS JobOwner,

    j.enabled,

    j.description

FROM dbo.sysjobs AS j

WHERE j.name =
      N'DEMO - Least Privilege';
GO



/*==============================================================================
    17. SPRÓBUJ URUCHOMIĆ WŁASNY JOB

    SQL Server Agent musi działać.
==============================================================================*/

PRINT '';
PRINT '===============================================================';
PRINT '17. Próba uruchomienia własnego joba';
PRINT '===============================================================';
GO


EXECUTE AS LOGIN = N'SQLDeployDemo';
GO


BEGIN TRY

    EXEC msdb.dbo.sp_start_job
        @job_name =
            N'DEMO - Least Privilege';

    PRINT '';
    PRINT 'Polecenie uruchomienia joba zostało przekazane Agentowi.';

END TRY

BEGIN CATCH

    PRINT '';
    PRINT 'Informacja z SQL Server Agent:';
    PRINT ERROR_MESSAGE();

END CATCH;
GO


REVERT;
GO



/*==============================================================================
    18. FINALNE PODSUMOWANIE
==============================================================================*/

USE [master];
GO


PRINT '';
PRINT '===============================================================';
PRINT '18. FINALNE PODSUMOWANIE';
PRINT '===============================================================';
PRINT '';
GO


SELECT
    LoginName =
        sp.name,

    IsSysadmin =
        IS_SRVROLEMEMBER
        (
            N'sysadmin',
            sp.name
        ),

    IsDbCreator =
        IS_SRVROLEMEMBER
        (
            N'dbcreator',
            sp.name
        )

FROM sys.server_principals AS sp

WHERE sp.name =
      N'SQLDeployDemo';
GO



SELECT
    MemberName =
        MemberPrincipal.name,

    ServerRole =
        RolePrincipal.name

FROM sys.server_role_members AS RoleMember

INNER JOIN sys.server_principals AS RolePrincipal
    ON RolePrincipal.principal_id =
       RoleMember.role_principal_id

INNER JOIN sys.server_principals AS MemberPrincipal
    ON MemberPrincipal.principal_id =
       RoleMember.member_principal_id

WHERE MemberPrincipal.name =
      N'SQLDeployDemo'

ORDER BY
    RolePrincipal.name;
GO



/*==============================================================================
    OSTATECZNY PRZEKAZ DEMO

        SQLDeployDemo

        MOŻE:
        ----------------------------------
        + tworzyć bazy
        + korzystać z VIEW SERVER STATE
        + widzieć bazy
        + tworzyć własne joby
        + uruchamiać własne joby

        NIE MOŻE:
        ----------------------------------
        - zrobić siebie sysadminem
        - dowolnie konfigurować instancji
        - przejąć pełnej kontroli nad SQL Server

        Czyli:

        LEAST PRIVILEGE

        zamiast

        SYSADMIN
==============================================================================*/


/*==============================================================================
    99. CLEANUP

    ODKOMENTUJ PO NAGRANIU
==============================================================================*/

/*

USE [msdb];
GO

IF EXISTS
(
    SELECT 1
    FROM dbo.sysjobs
    WHERE name = N'DEMO - Least Privilege'
)
BEGIN

    EXEC dbo.sp_delete_job
        @job_name =
            N'DEMO - Least Privilege';

END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'SQLDeployDemo'
)
BEGIN

    DROP USER [SQLDeployDemo];

END;
GO


USE [master];
GO


IF DB_ID
(
    N'DemoDeploymentDatabase'
) IS NOT NULL
BEGIN

    ALTER DATABASE [DemoDeploymentDatabase]
        SET SINGLE_USER
        WITH ROLLBACK IMMEDIATE;

    DROP DATABASE [DemoDeploymentDatabase];

END;
GO


IF IS_SRVROLEMEMBER
(
    N'DeployOperators',
    N'SQLDeployDemo'
) = 1
BEGIN

    ALTER SERVER ROLE [DeployOperators]
        DROP MEMBER [SQLDeployDemo];

END;
GO


IF IS_SRVROLEMEMBER
(
    N'dbcreator',
    N'SQLDeployDemo'
) = 1
BEGIN

    ALTER SERVER ROLE [dbcreator]
        DROP MEMBER [SQLDeployDemo];

END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.server_principals
    WHERE name = N'SQLDeployDemo'
)
BEGIN

    DROP LOGIN [SQLDeployDemo];

END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.server_principals
    WHERE name = N'DeployOperators'
      AND type = 'R'
)
BEGIN

    DROP SERVER ROLE [DeployOperators];

END;
GO

*/