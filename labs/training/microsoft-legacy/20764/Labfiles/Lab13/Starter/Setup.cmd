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

REM - Start a workload
ECHO Setup complete: Creating database load...
SQLCMD -S MIA-SQL -U PromoteApp13 -P Pa^$^$w0rd -b -i %SUBDIR%Setupfiles\workload1.sql > %SUBDIR%Setupfiles\wk1.txt

DEL %SUBDIR%Setupfiles\wk1.txt /Q /F

