-- Module 15 Exercise 2

-- Task 1 - examine foreign key constraint status
USE AdventureWorks;
GO
SELECT name, is_not_trusted, is_disabled
FROM sys.foreign_keys
WHERE parent_object_id = object_id('Accounts.ExchangeRate');

-- Task 2 - make the foreign key constraints trustworthy
ALTER TABLE Accounts.ExchangeRate WITH CHECK CHECK CONSTRAINT FK_ExchangeRate_CurrencyCode_from;
ALTER TABLE Accounts.ExchangeRate WITH CHECK CHECK CONSTRAINT FK_ExchangeRate_CurrencyCode_to;
GO

