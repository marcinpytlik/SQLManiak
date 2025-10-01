-- scripts/02_workload_psp.sql
USE PSP_Lab;
GO
-- Rzadki kubełek
EXEC dbo.GetOrdersByRegion @region = 77;
-- Gęsty kubełek
EXEC dbo.GetOrdersByRegion @region = 1;
GO 50
