@Echo Off
ECHO Preparing the demo environment...

REM - Get current directory
SET SUBDIR=%~dp0

REM - Restart SQL Server Service to force closure of any open connections
NET STOP SQLAGENT$SQL2
NET STOP MSSQL$SQL2
NET START MSSQL$SQL2
NET START SQLAGENT$SQL2
NET STOP MSSQLLaunchpad
NET STOP SQLSERVERAGENT
NET STOP MSSQLSERVER
NET START MSSQLSERVER
NET START SQLSERVERAGENT
NET START MSSQLLaunchpad

REM - Run SQL Script to prepare the database environment
ECHO Preparing Databases...
SQLCMD -S MIA-SQL\SQL2 -E -i %SUBDIR%SetupFiles\Setup2.sql 
SQLCMD -E -i %SUBDIR%SetupFiles\Setup.sql 

ECHO Deleting email...
DEL c:\inetpub\mailroot\drop\*.* /Q













