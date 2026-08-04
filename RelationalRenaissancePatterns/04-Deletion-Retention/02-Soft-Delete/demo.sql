/*
    Relacyjny Renesans — Soft Delete
    Logiczne usuwanie danych.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DROP TABLE IF EXISTS dbo.Customers;
GO
CREATE TABLE dbo.Customers
(
    CustomerId int IDENTITY PRIMARY KEY,
    Email nvarchar(320) NOT NULL,
    IsDeleted bit NOT NULL CONSTRAINT DF_Customers_IsDeleted DEFAULT 0,
    DeletedAt datetime2 NULL
);
GO
INSERT dbo.Customers(Email) VALUES (N'a@example.com'),(N'b@example.com');
UPDATE dbo.Customers SET IsDeleted = 1, DeletedAt = SYSUTCDATETIME() WHERE Email = N'a@example.com';
SELECT * FROM dbo.Customers WHERE IsDeleted = 0;
GO
