@Echo Off
ECHO Preparing the demo environment...

REM - Get current directory
SET SUBDIR=%~dp0


REM - Restart SQL Server Service to force closure of any open connections

NET STOP MSSQLLaunchpad
NET STOP SQLSERVERAGENT
NET STOP MSSQLSERVER

REM Create Data Folder
RmDir %SUBDIR%Data /S /Q
MD %SUBDIR%Data

NET START MSSQLSERVER
NET START SQLSERVERAGENT
NET START MSSQLLaunchpad


REM - Run SQL Script to prepare the database environment
ECHO Preparing Databases...
SQLCMD -E -i %SUBDIR%SetupFiles\Setup.sql









