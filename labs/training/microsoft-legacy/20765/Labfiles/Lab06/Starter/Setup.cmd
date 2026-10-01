@Echo Off
ECHO Preparing the lab environment...

REM - Get current directory
SET SUBDIR=%~dp0

REM - Restart SQL Server Service
NET STOP SQLSERVERAGENT
NET STOP SQLPBDMS
NET STOP SQLPBENGINE
NET STOP MSSQLLaunchpad
NET STOP MSSQLSERVER
NET START MSSQLSERVER
NET START SQLPBDMS
NET START SQLPBENGINE
NET START MSSQLLaunchpad
NET START SQLSERVERAGENT


REM - Run SQL Script to prepare the database environment
ECHO Configuring databases...
SQLCMD -E -i %SUBDIR%SetupFiles\Setup.sql 

REM - Install SQL Server upgrade Advisor. Needed for stretch database demo
ECHO Installing SQL Server upgrade advisor.
%SUBDIR%SetupFiles\SQLAdvisor.msi /qn ADDLOCAL=ALL UAINSTALLDIR="c:\Upgrade Advisor"



