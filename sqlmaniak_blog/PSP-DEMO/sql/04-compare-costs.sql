
-- 04-compare-costs.sql
-- Porównanie IO/CPU dla różnych wartości parametru
USE PSP_Demo;
GO

SET NOCOUNT ON;
SET STATISTICS IO, TIME ON;

DECLARE @Few INT = (SELECT TOP 1 CustomerID FROM dbo.Customers WHERE CustomerID > 1);

PRINT '== SELEKTYWNY (MAŁO WIERSZY) ==';
EXEC dbo.GetOrdersByCustomer @CustomerID = @Few;

PRINT '== NIESelektywny (WIELE WIERSZY) ==';
EXEC dbo.GetOrdersByCustomer @CustomerID = 1;

SET STATISTICS IO, TIME OFF;
GO

-- Dodatkowo: podgląd wariantów w Query Store dla tej procedury
SELECT qsq.query_id,
       qsp.plan_id,
       qsp.is_parameter_sensitive_plan,
       qsp.last_compile_start_time,
       qsp.last_execution_time
FROM sys.query_store_plan AS qsp
JOIN sys.query_store_query AS qsq ON qsq.query_id = qsp.query_id
WHERE qsq.object_id = OBJECT_ID('dbo.GetOrdersByCustomer')
ORDER BY qsp.last_execution_time DESC;
