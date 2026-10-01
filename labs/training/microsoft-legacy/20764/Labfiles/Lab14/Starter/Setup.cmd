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

REM - rename .ps1.txt files to .ps1
FOR /R %SUBDIR%.. %%i IN (*.ps1.txt) DO @REN %%~fi %%~ni

REM change the service account password of the mssql$sql2 service
NET STOP mssql$sql2
powershell -ExecutionPolicy Bypass -File %SUBDIR%SetupFiles\change_sql2_pass.ps1
REM should fail - needed to generate an error log file
NET START mssql$sql2

REM - Run PowerShell script to set up AD users and groups needed for this lab
powershell -ExecutionPolicy Bypass -File %SUBDIR%SetupFiles\invoke_dc_commands.ps1

REM - Run SQL Script to prepare the database environment
ECHO Preparing Databases...
SQLCMD -E -i %SUBDIR%SetupFiles\Setup.sql 











