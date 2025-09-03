SET SUBDIR=%~dp0

SQLCMD -S MIA-SQL -U PromoteApp13 -P Pa^$^$w0rd -b -i %SUBDIR%Setupfiles\workload1.sql -o %SUBDIR%Setupfiles\wk1.txt
DEL %SUBDIR%Setupfiles\wk1.txt /Q /F
