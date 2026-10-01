-- Demonstration - connecting to an Azure SQL Database

--1. switch to the TestPSDB database

--2. execute the following query
SELECT db_name() AS dbname, @@servername AS servername, getutcdate() AS datetimeutc

--3. Open Windows PowerShell and type the following command:
SQLCMD -S <your server name>.database.windows.net -d TestPSDB -U psUser -Q "SELECT db_name() AS dbname, @@servername AS servername, getutcdate() AS datetimeutc"
-- enter the password Pa$$w0rd when prompted
