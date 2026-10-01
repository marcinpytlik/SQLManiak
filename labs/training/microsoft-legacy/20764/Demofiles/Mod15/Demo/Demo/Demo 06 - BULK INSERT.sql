-- Module 15 - Demo 6

-- Step 1 - query the contents of the dbo.Currency
-- demonstrate that the table is empty
USE Finance;
GO
SELECT * FROM dbo.Currency;
GO

-- Step 2 - bulk insert from a text file
BULK INSERT Finance.dbo.Currency
FROM 'D:\Demofiles\Mod15\data\currency.txt'
WITH (FIELDTERMINATOR ='|',
      ROWTERMINATOR ='\n'
);
GO

-- Step 3 - query the contents of the dbo.Currency
-- demonstrate that the table is now populated
SELECT * FROM dbo.Currency;
GO