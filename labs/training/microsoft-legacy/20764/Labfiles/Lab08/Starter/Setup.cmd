@Echo Off
ECHO Preparing the demo environment...

REM - Get current directory
SET SUBDIR=%~dp0

REM - Restart SQL Server Service to force closure of any open connections
NET STOP MSSQLLaunchpad 
NET STOP SQLSERVERAGENT
NET STOP MSSQLSERVER
NET STOP SQLAGENT$SQL2
NET STOP MSSQL$SQL2
NET START MSSQLSERVER
NET START MSSQL$SQL2
NET START SQLSERVERAGENT
NET START SQLAGENT$SQL2
NET START MSSQLLaunchpad 

REM - Run SQL Script to prepare the database environment
ECHO Preparing Databases...
SQLCMD -S MIA-SQL\SQL2 -E -i %SUBDIR%SetupFiles\Setup2.sql
SQLCMD -E -i %SUBDIR%SetupFiles\Setup.sql

ECHO Creating user...
ren %SUBDIR%SetupFiles\CreateUser.ps1.txt CreateUser.ps1
Powershell.exe %SUBDIR%SetupFiles\CreateUser.ps1
ren %SUBDIR%SetupFiles\CreateUser.ps1 CreateUser.ps1.txt

DEL %SUBDIR%*.txt
DEL %SUBDIR%*.bak
DEL %SUBDIR%*.sql

Echo Editing SQL Server Agent Registry Key
ren %SUBDIR%SetupFiles\SQL2AgentSecurity.reg.txt SQL2AgentSecurity.reg
RegEdit /s %SUBDIR%SetupFiles\SQL2AgentSecurity.reg
ren %SUBDIR%SetupFiles\SQL2AgentSecurity.reg SQL2AgentSecurity.reg.txt

ren %SUBDIR%SetupFiles\SQL3AgentSecurity.reg.txt SQL3AgentSecurity.reg
RegEdit /s %SUBDIR%SetupFiles\SQL3AgentSecurity.reg
ren %SUBDIR%SetupFiles\SQL3AgentSecurity.reg SQL3AgentSecurity.reg.txt

ren %SUBDIR%SetupFiles\SQLAgentSecurity.reg.txt SQLAgentSecurity.reg
RegEdit /s %SUBDIR%SetupFiles\SQLAgentSecurity.reg
ren %SUBDIR%SetupFiles\SQLAgentSecurity.reg SQLAgentSecurity.reg.txt







