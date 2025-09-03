@Echo Off
ECHO Preparing the lab environment...

REM - Get current directory
SET SUBDIR=%~dp0

REM - Restart SQL Server Service
NET STOP SQLSERVERAGENT
NET STOP MSSQLSERVER
NET STOP SQLAGENT$SQL2
NET STOP MSSQL$SQL2
NET START MSSQLSERVER
NET START MSSQL$SQL2
NET START SQLAGENT$SQL2

REM - Run SQL Script to prepare the database environment
ECHO Configuring databases...
SQLCMD -S MIA-SQL\SQL2 -E -i %SUBDIR%SetupFiles\Setup2.sql
SQLCMD -E -i %SUBDIR%SetupFiles\Setup.sql

REM Sabotage AdventurWorks
ECHO Sabotaging databases...
NET STOP MSSQLSERVER
DEL D:\Labfiles\Lab07\Starter\SetupFiles\HumanResources.mdf /Q
COPY %SUBDIR%SetupFiles\InternetSales.mdf.txt %SUBDIR%SetupFiles\InternetSales.mdf /Y
NET START MSSQLSERVER
NET START SQLSERVERAGENT

PAUSE





