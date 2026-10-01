USE Adventureworks 
GO

-- Insert an additional 10000 rows
SET NOCOUNT ON;
DECLARE @Counter int = 0;
WHILE @Counter < 10000 BEGIN
  INSERT INTO [Sales].[SalesOrderHeader] 
           ([RevisionNumber],[OrderDate],[DueDate],[Status],[OnlineOrderFlag],[CustomerID],[BillToAddressID],[ShipToAddressID],[ShipMethodID],[SubTotal],[TaxAmt],[Freight],[rowguid],[ModifiedDate])
     VALUES
           (3, GETDATE(), GETDATE(), 5, 0, 29825, 985, 985, 5, 100, 10, 10, NEWID(), GETDATE());
SET @Counter += 1;
END;
GO

