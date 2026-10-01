@ECHO OFF

ECHO Preparing Environment...
NET STOP SQLAGENT$SQL2
NET STOP MSSQL$SQL2
REN "C:\Program Files\Microsoft SQL Server\MSSQL13.SQL2\MSSQL\DATA\master.mdf" "master.AV0001"
