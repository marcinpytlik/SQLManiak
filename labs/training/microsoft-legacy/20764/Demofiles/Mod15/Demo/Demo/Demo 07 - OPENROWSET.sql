-- Module 15 - Demo 7

-- Step 1 - query the contents of the dbo.SalesTaxRate
-- demonstrate that the table is empty
USE Finance;
GO
SELECT * FROM dbo.SalesTaxRate;
GO

-- Step 2 - demonstrate a SELECT statement with OPENROWSET
SELECT * FROM OPENROWSET (BULK 'D:\Demofiles\Mod15\Data\SalesTaxRate.txt',
FORMATFILE = 'D:\Demofiles\Mod15\Data\SalesTaxRate.xml') AS x;

--Step 3 - demonstrate that the output of OPENROWSET can be filtered
SELECT * FROM OPENROWSET (BULK 'D:\Demofiles\Mod15\Data\SalesTaxRate.txt',
FORMATFILE = 'D:\Demofiles\Mod15\Data\SalesTaxRate.xml') AS x
WHERE x.SalesTaxRateID = 29;

-- Step 4 - use the SELECT statement from step 2 to insert data to dbo.SalesTaxRate
INSERT dbo.SalesTaxRate
(SalesTaxRateID,StateProvinceID,TaxType,TaxRate,Name,rowguid,ModifiedDate)
SELECT * FROM OPENROWSET (BULK 'D:\Demofiles\Mod15\Data\SalesTaxRate.txt',
FORMATFILE = 'D:\Demofiles\Mod15\Data\SalesTaxRate.xml') AS x;

-- Step 5 - query the contents of the dbo.SalesTaxRate
-- demonstrate that the table is now populated with data
SELECT * FROM dbo.SalesTaxRate;
GO
