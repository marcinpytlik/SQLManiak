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


REM - Create Demo folder
mkdir D:\Demofiles\Mod11\Demo



