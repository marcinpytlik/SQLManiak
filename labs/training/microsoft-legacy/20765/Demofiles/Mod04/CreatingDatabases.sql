
-- Create a database
USE master;
GO
CREATE DATABASE DemoDB2
ON 
( NAME = DemoDB2_dat, 
  FILENAME = 'M:\Data\DemoDB2.mdf',   
  SIZE = 100MB, MAXSIZE = 500MB,  
  FILEGROWTH = 20% 
)
LOG ON
( NAME = DemoDB2_log,
  FILENAME = 'L:\Logs\DemoDB2.ldf',  
  SIZE = 20MB, 
  MAXSIZE = UNLIMITED,  
  FILEGROWTH = 10MB 
);
GO

--	View database info
EXEC sp_helpdb DemoDB2

