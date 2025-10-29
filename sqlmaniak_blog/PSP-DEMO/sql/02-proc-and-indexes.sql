
-- 02-proc-and-indexes.sql
USE PSP_Demo;
GO

-- (opcjonalnie) indeks wspierający selektywny seek po CustomerID + OrderDate
CREATE INDEX IX_Orders_CustomerID_OrderDate ON dbo.Orders(CustomerID, OrderDate) INCLUDE (TotalDue);
GO

CREATE OR ALTER PROCEDURE dbo.GetOrdersByCustomer
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OrderID, OrderDate, TotalDue
    FROM dbo.Orders
    WHERE CustomerID = @CustomerID
    ORDER BY OrderDate DESC;
END
GO
