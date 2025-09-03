-- Module 15 - Demo 2

-- Step 1 - connect this query window to your copy of AdventureWorksLT

-- Step 2 - create a partitioned table
DROP TABLE IF EXISTS SalesLT.RegionScores;

IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'ps_regions')
	DROP PARTITION SCHEME ps_regions

IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'pf_region_code')
	DROP PARTITION FUNCTION pf_region_code
GO

CREATE PARTITION FUNCTION pf_region_code (int) AS RANGE LEFT FOR VALUES (100, 200, 300);
GO

CREATE PARTITION SCHEME ps_regions AS PARTITION pf_region_code ALL TO ([PRIMARY]);
GO
-- Creates a partitioned table that uses ps_regions to partition col1
CREATE TABLE SalesLT.RegionScores 
(region_code int PRIMARY KEY, 
 score_date date NOT NULL,
 score smallint NOT NULL
)
ON ps_regions (region_code);
GO

-- Step 3 - create a table which matches the schema of the partitioned table
-- insert some data which corresponds to partition 1 of SalesLT.RegionScores
DROP TABLE IF EXISTS SalesLT.RegionScoresStaging 
GO
CREATE TABLE SalesLT.RegionScoresStaging 
(region_code int PRIMARY KEY, 
 score_date date NOT NULL,
 score smallint NOT NULL
)
GO
ALTER TABLE SalesLT.RegionScoresStaging ADD CONSTRAINT ck_region_code_le_100 CHECK (region_code <= 100);
GO

INSERT SalesLT.RegionScoresStaging 
values (10, '20160301',50),
(20, '20160302',51),
(30, '20160303',52)
GO

-- Step 4 - switch partition 1 of SalesLT.RegionScores with the staging table
ALTER TABLE SalesLT.RegionScoresStaging SWITCH TO SalesLT.RegionScores PARTITION 1;
GO

-- Step 5 - demonstrate that the SalesLT.RegionScoresStaging table is empty,
-- and that SalesLT.RegionScores contains the inserted data
SELECT * FROM SalesLT.RegionScoresStaging;
GO
SELECT * FROM SalesLT.RegionScores;
GO

-- Step 6 - create three identical tables to demonstrate
-- partition switch between unpartitioned tables used for data load
-- SalesLT.ShippingRate is the "live" data; add rows to it
DROP TABLE IF EXISTS SalesLT.ShippingRate;
DROP TABLE IF EXISTS SalesLT.ShippingRateStaging;
DROP TABLE IF EXISTS SalesLT.ShippingRateWork;
GO

CREATE TABLE SalesLT.ShippingRate
(RateId INT PRIMARY KEY,
 RateCode varchar(10) NOT NULL,
 RatePerKilo decimal(10,2) NOT NULL
);

CREATE TABLE SalesLT.ShippingRateStaging
(RateId INT PRIMARY KEY,
 RateCode varchar(10) NOT NULL,
 RatePerKilo decimal(10,2) NOT NULL
);

CREATE TABLE SalesLT.ShippingRateWork
(RateId INT PRIMARY KEY,
 RateCode varchar(10) NOT NULL,
 RatePerKilo decimal(10,2) NOT NULL
);
GO

INSERT SalesLT.ShippingRate (RateId, RateCode, RatePerKilo)
values (1,'A1',0.98),
(2,'A2',1.23),
(3,'B1',2.34);

-- Step 7 - add data to the SalesLT.ShippingRateStaging table,
-- representing a data load
INSERT SalesLT.ShippingRateStaging (RateId, RateCode, RatePerKilo)
values (1,'X1',5.43),
(2,'Y2',4.32),
(3,'Z1',3.21);

-- Step 8 - switch the data. The SalesLT.ShippingRateWork table is 
-- needed so that there's always an empty table to switch to
ALTER TABLE SalesLT.ShippingRate SWITCH TO SalesLT.ShippingRateWork;
GO
ALTER TABLE SalesLT.ShippingRateStaging SWITCH TO SalesLT.ShippingRate;
GO

-- Step 9 - demonstrate that SalesLT.ShippingRate contains the new data
SELECT * FROM SalesLT.ShippingRate;

-- Step 10 - drop the demonstration objects
DROP TABLE IF EXISTS SalesLT.ShippingRate;
DROP TABLE IF EXISTS SalesLT.ShippingRateStaging;
DROP TABLE IF EXISTS SalesLT.ShippingRateWork;
DROP TABLE IF EXISTS SalesLT.RegionScores;
DROP TABLE IF EXISTS SalesLT.RegionScoresStaging;
IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'ps_regions')
	DROP PARTITION SCHEME ps_regions

IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'pf_region_code')
	DROP PARTITION FUNCTION pf_region_code
GO
