
-- 03-run-scenarios.sql
-- Uruchamia scenariusze wymuszające różne selektywności
USE PSP_Demo;
GO

-- Wyczyść cache dla czystości porównania (nie wymagane, ale pomocne w demie)
DBCC FREEPROCCACHE WITH NO_INFOMSGS;
GO

-- Scenariusz A: bardzo selektywny (klient z małą liczbą zamówień)
DECLARE @Few INT = (SELECT TOP 1 CustomerID FROM dbo.Customers WHERE CustomerID > 1);
EXEC dbo.GetOrdersByCustomer @CustomerID = @Few;
EXEC dbo.GetOrdersByCustomer @CustomerID = @Few;
EXEC dbo.GetOrdersByCustomer @CustomerID = @Few;

-- Scenariusz B: bardzo nieselectywny (mega klient)
EXEC dbo.GetOrdersByCustomer @CustomerID = 1;
EXEC dbo.GetOrdersByCustomer @CustomerID = 1;
EXEC dbo.GetOrdersByCustomer @CustomerID = 1;

-- Naprzemiennie, by utrwalić warianty
EXEC dbo.GetOrdersByCustomer @CustomerID = @Few;
EXEC dbo.GetOrdersByCustomer @CustomerID = 1;
EXEC dbo.GetOrdersByCustomer @CustomerID = @Few;
EXEC dbo.GetOrdersByCustomer @CustomerID = 1;

PRINT 'DONE. Sprawdź Query Store i warianty planów.';
