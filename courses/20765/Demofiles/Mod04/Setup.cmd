@Echo Off
ECHO Preparing the lab environment...

REM - Get current directory
SET SUBDIR=%~dp0

REM - Run SQL Script to reset SQL Server configuration
ECHO Configuring SQL Server...
SQLCMD -E -i %SUBDIR%SetupFiles\Reset.sql > NUL

REM - Restart SQL Server Service
NET STOP MSSQLLaunchpad
NET STOP SQLSERVERAGENT
NET STOP MSSQLSERVER
NET START MSSQLSERVER
NET START SQLSERVERAGENT
NET START MSSQLLaunchpad

NET STOP SQLAGENT$SQL2
NET STOP MSSQL$SQL2
NET START MSSQL$SQL2
NET START SQLAGENT$SQL2

REM - Run SQL Script to prepare the database environment
ECHO Preparing Databases...
SQLCMD -E -i %SUBDIR%SetupFiles\Setup.sql > NUL
SQLCMD -S MIA-SQL\SQL2 -E -i %SUBDIR%SetupFiles\Setup.sql > NUL

REM Create folders for database files, existing remote drives must exist, see course notes
ECHO Creating folders for database files
MD L:\Logs > NUL
MD M:\Data > NUL
MD N:\Data > NUL
DEL T:\tempdb.* /Q
DEL T:\templog.* /Q






