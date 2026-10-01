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

REM - clear out the Export directory
DEL %SUBDIR%Export\* /Q /F

REM - remove and replace the prospect_export directory
RMDIR %SUBDIR%prospect_export /Q /S
XCOPY %SUBDIR%Setupfiles\prospect_export %SUBDIR%prospect_export /S /Y /Q /I

REM - remove and replace the FixedAssets directory
RMDIR %SUBDIR%FixedAssets /Q /S
XCOPY %SUBDIR%Setupfiles\FixedAssets %SUBDIR%FixedAssets /S /Y /Q /I
