-- Module 15 Exercise 3

-- Task 1 - clear down the contents of the Accounts.ExchangeRate table
USE AdventureWorks;
GO
TRUNCATE TABLE Accounts.ExchangeRate;

-- Task 2 - edit the following query to insert the contents of the currency_exchange_rates.txt file
-- in D:\Labfiles\Lab15\Starter\Import to Accounts.ExchangeRate using BULK INSERT
-- Include an option to allow constraints to be checked during the import.
BULK INSERT AdventureWorks.Accounts.ExchangeRate
FROM 'D:\Labfiles\Lab15\Starter\Import\currency_exchange_rates.txt'
WITH ( FIELDTERMINATOR =',',
       ROWTERMINATOR ='\n',
       CHECK_CONSTRAINTS
     );
GO

-- Task 3 - examine foreign key constraint status
SELECT name, is_not_trusted, is_disabled
FROM sys.foreign_keys
WHERE parent_object_id = object_id('Accounts.ExchangeRate');
