
-- 01-create-data.sql
-- Tworzy schemat i generuje mocno skośne dane
USE PSP_Demo;
GO

IF OBJECT_ID('dbo.Customers') IS NOT NULL DROP TABLE dbo.Customers;
IF OBJECT_ID('dbo.Orders') IS NOT NULL DROP TABLE dbo.Orders;
GO

CREATE TABLE dbo.Customers
(
    CustomerID INT IDENTITY(1,1) CONSTRAINT PK_Customers PRIMARY KEY,
    Name       NVARCHAR(100) NOT NULL
);

CREATE TABLE dbo.Orders
(
    OrderID     BIGINT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerID  INT NOT NULL,
    OrderDate   DATETIME2(0) NOT NULL DEFAULT (SYSUTCDATETIME()),
    TotalDue    MONEY NOT NULL,
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID)
);

-- 10 000 klientów
;WITH N AS (
    SELECT TOP (10000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT INTO dbo.Customers(Name)
SELECT CONCAT(N'n', n) FROM N;

-- Skos: 1 "mega klient" (CustomerID = 1) dostaje 200 000 zamówień,
--       9 999 klientów dostaje po 0-5 zamówień
;WITH Big AS (
    SELECT TOP (200000) 1 AS CustomerID
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
),
Small AS (
    SELECT c.CustomerID, x.k
    FROM dbo.Customers c
    CROSS APPLY (SELECT TOP (ABS(CHECKSUM(NEWID())) % 6) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS k FROM sys.all_objects) x
    WHERE c.CustomerID > 1
)
INSERT INTO dbo.Orders(CustomerID, OrderDate, TotalDue)
SELECT 1, DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, SYSUTCDATETIME()), (ABS(CHECKSUM(NEWID())) % 10000) / 10.0
FROM Big
UNION ALL
SELECT s.CustomerID, DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, SYSUTCDATETIME()), (ABS(CHECKSUM(NEWID())) % 10000) / 10.0
FROM Small s;
GO

-- Pomocnicze indeksy
CREATE INDEX IX_Orders_CustomerID ON dbo.Orders(CustomerID);
GO
