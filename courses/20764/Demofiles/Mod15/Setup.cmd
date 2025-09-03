@Echo Off
ECHO Preparing the lab environment...

REM - Get current directory
SET SUBDIR=%~dp0

REM - Restart SQL Server Service to force closure of any open connections
NET STOP MSSQLLaunchpad
NET STOP SQLSERVERAGENT
NET STOP MSSQLSERVER
NET START MSSQLSERVER
NET START SQLSERVERAGENT
NET START MSSQLLaunchpad

REM - Run SQL Script to prepare the database environment
ECHO Preparing Databases...
SQLCMD -E -i %SUBDIR%SetupFiles\Setup.sql

REM - Copy an empty dtsx file into the project just in case setup is rerun
COPY %SUBDIR%SSISProject\SSISProject\Package_empty.dtsx %SUBDIR%SSISProject\SSISProject\Package.dtsx /B /Y

REM - clear out the bcp directory
DEL %SUBDIR%bcp\*.* /Q /F

REM - clear out the dacpac directory
DEL %SUBDIR%dacpac\*.* /Q /F











