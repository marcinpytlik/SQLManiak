-- Module 4 - Demo 1

-- Step 1 - connect this query window to your copy of AdventureWorksLT

-- Step 2 - create a system-versioned temporary table
CREATE TABLE dbo.Manager
( ManagerId int NOT NULL PRIMARY KEY,
  ManagerName nvarchar(50) NOT NULL,
  ManagerPassword varbinary(200) NOT NULL,
  ValidFrom datetime2 GENERATED ALWAYS AS ROW START NOT NULL, 
  ValidTo datetime2 GENERATED ALWAYS AS ROW END NOT NULL, 
  ChangedBy sysname NOT NULL CONSTRAINT DF_Employee_ChangedBy DEFAULT  (SUSER_SNAME()),
  PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo) 
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ManagerHistory));
GO

-- Step 3 - insert example data
INSERT dbo.Manager (ManagerId, ManagerName, ManagerPassword)
VALUES (1, N'superuser', 0x3EED6B62548EC64A90E5D5D186FC9E5C),
(2, N'PeledYael', 0x19EF561D56A24D42A54169BD3DE23652),
(3, N'DavisSara', 0xD42025F8D7A67248AC36C5C8E955FA71);
GO

-- Step 4 - update a row
UPDATE dbo.Manager 
SET ManagerPassword = 0x3EED6B62548EC64A90E5D5D186FCFFFF,
ManagerName = 'administrator'
WHERE ManagerId = 1

-- Step 5 - examine temporal table component tables
SELECT * FROM dbo.Manager;

SELECT * FROM dbo.ManagerHistory;

-- Step 6 - demonstrate FOR SYSTEM TIME ALL when querying a temporal table
-- ALL shows all data in both tables
SELECT * FROM dbo.Manager 
FOR SYSTEM_TIME ALL;

-- Step 7 - demonstrate FOR SYSTEM TIME AS OF when querying a temporal table
-- AS OF shows a point in time
-- Note that this returns the original data
DECLARE @t datetime2 = (SELECT TOP(1) ValidFrom FROM dbo.ManagerHistory WHERE ManagerId = 1)
SELECT * FROM dbo.Manager 
FOR SYSTEM_TIME AS OF @t
GO

-- Step 8 - demonstrate that the history table cannot be edited
-- (both commands will generate an error)
UPDATE dbo.ManagerHistory SET ChangedBy = 'maliciousUser';
GO
INSERT dbo.ManagerHistory (ManagerId, ManagerName, ManagerPassword)
VALUES (99, N'superuser', 0x3EED6B62548EC64A90E5D5D186FC9E5C)
GO

-- Step 9 - demonstrate that a user with sufficient permissions can
-- insert misleading data into the ChangedBy column:
UPDATE dbo.Manager 
SET ManagerPassword = 0x0A0B,
ManagerName = 'hacked', ChangedBy = 'maliciousUser'
WHERE ManagerId = 1

-- Step 10 - examine temporal table component tables
SELECT * FROM dbo.Manager;

SELECT * FROM dbo.ManagerHistory;

-- Step 11 - tear down demonstration objects
ALTER TABLE dbo.Manager SET (SYSTEM_VERSIONING = OFF);
DROP TABLE dbo.Manager;
DROP TABLE dbo.ManagerHistory;


