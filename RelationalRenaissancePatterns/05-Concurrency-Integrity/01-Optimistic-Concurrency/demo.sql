/*
    Relacyjny Renesans — Optimistic Concurrency
    Kontrola konfliktu przez rowversion.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DROP TABLE IF EXISTS dbo.Products;
GO
CREATE TABLE dbo.Products
(
    ProductId int IDENTITY PRIMARY KEY,
    Name nvarchar(100) NOT NULL,
    Price decimal(12,2) NOT NULL,
    Version rowversion NOT NULL
);
GO
INSERT dbo.Products(Name, Price) VALUES (N'Książka', 99.00);
GO
DECLARE @Version binary(8);
SELECT @Version = Version FROM dbo.Products WHERE ProductId = 1;

UPDATE dbo.Products
SET Price = 109.00
WHERE ProductId = 1
  AND Version = @Version;

IF @@ROWCOUNT = 0
    THROW 50001, 'Rekord został zmieniony przez inny proces.', 1;
GO
