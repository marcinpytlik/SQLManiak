USE master;
GO

IF EXISTS(SELECT * FROM sys.databases WHERE name = 'MarketDev')
	DROP DATABASE MarketDev;
GO

CREATE DATABASE MarketDev ON  PRIMARY 
(  NAME = N'MarketDev', 
   FILENAME = N'$(SUBDIR)Setupfiles\MarketDev.mdf' , 
   SIZE = 5MB, 
   FILEGROWTH = 1024KB 
)
 LOG ON 
( NAME = N'MarketDev_log', 
  FILENAME = N'$(SUBDIR)Setupfiles\MarketDev_log.ldf' , 
  SIZE = 1MB, 
  FILEGROWTH = 10%
);
GO

ALTER DATABASE MarketDev SET RECOVERY SIMPLE;
GO

IF EXISTS(SELECT * FROM sys.databases WHERE name = 'Research')
	DROP DATABASE Research;
GO

CREATE DATABASE Research ON  PRIMARY 
(  NAME = N'Research', 
   FILENAME = N'$(SUBDIR)Setupfiles\Research.mdf' , 
   SIZE = 5MB, 
   FILEGROWTH = 1024KB 
)
 LOG ON 
( NAME = N'Research_log', 
  FILENAME = N'$(SUBDIR)Setupfiles\Research_log.ldf' , 
  SIZE = 1MB, 
  FILEGROWTH = 10%
);
GO

ALTER DATABASE Research SET RECOVERY SIMPLE;
GO