@Echo Off
ECHO Preparing the demo environment...

REM - Get current directory
SET SUBDIR=%~dp0

REM - Restart SQL Server Service to force closure of any open connections
NET STOP SQLSERVERAGENT
NET STOP MSSQLLaunchpad
NET STOP MSSQLSERVER
NET START MSSQLSERVER
NET START MSSQLLaunchpad
NET START SQLSERVERAGENT

REM - Setting Up Windows Share
IF EXIST d:\smbshare goto :shareSetup
REM - Create required Directory
mkdir d:\smbshare

:shareSetup
REM - Set up share
net share smbshare=d:\smbshare /Grant:Adventureworks\ServiceAcct,FULL

:end