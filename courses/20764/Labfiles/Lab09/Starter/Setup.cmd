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

REM - Run PowerShell script to set up AD users and groups needed for this lab
powershell -ExecutionPolicy Bypass -File %SUBDIR%SetupFiles\invoke_dc_commands.ps1

REM - Run SQL Script to prepare the database environment
ECHO Preparing Databases...
SQLCMD -E -i %SUBDIR%SetupFiles\Setup.sql 

IF EXIST %SUBDIR%SalesLog RMDIR %SUBDIR%SalesLog /S /Q
MKDIR %SUBDIR%SalesLog

REM grant access to SalesLog for ExtractUser
icacls %SUBDIR%SalesLog /grant ADVENTUREWORKS\ExtractUser:(OI)(CI)F /T

REM deny access to SalesLog for ServiceAcct
icacls %SUBDIR%SalesLog /deny ADVENTUREWORKS\ServiceAcct:(OI)(CI)F /T

PAUSE










