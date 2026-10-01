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
FOR /R %SUBDIR% %%i IN (*.ps1.txt) DO @REN %%~fi %%~ni

REM - Run PowerShell script to set up AD users and groups needed for this lab
powershell -File %SUBDIR%SetupFiles\invoke_dc_commands.ps1

REM - Run SQL Script to prepare the database environment
ECHO Preparing Databases...
SQLCMD -E -i %SUBDIR%SetupFiles\Setup.sql 

IF EXIST %SUBDIR%ExportData RMDIR %SUBDIR%ExportData /S /Q
MKDIR %SUBDIR%ExportData

ECHO Hello World>%SUBDIR%ExportData\export.txt

IF EXIST %SUBDIR%ImportData RMDIR %SUBDIR%ImportData /S /Q
MKDIR %SUBDIR%ImportData

REM revoke access to Import/ExportData for the service account 
icacls %SUBDIR%ExportData /deny ADVENTUREWORKS\ServiceAcct:(OI)(CI)F /T
icacls %SUBDIR%ImportData /deny ADVENTUREWORKS\ServiceAcct:(OI)(CI)F /T

REM grant access to Import/ExportData for FileOps 
icacls %SUBDIR%ExportData /grant ADVENTUREWORKS\FileOps:(OI)(CI)F /T
icacls %SUBDIR%ImportData /grant ADVENTUREWORKS\FileOps:(OI)(CI)F /T








