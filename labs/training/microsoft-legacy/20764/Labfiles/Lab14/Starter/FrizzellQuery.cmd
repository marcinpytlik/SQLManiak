@ECHO OFF
sqlcmd -U Adventureworks\AnthonyFrizzell -P Pa$$w0rd -Q "SELECT GETDATE()" 
pause