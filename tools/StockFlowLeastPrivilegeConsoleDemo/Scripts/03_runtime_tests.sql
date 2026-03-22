--Invoke-Sqlcmd -ServerInstance "localhost" -Database "StockFlowDb" -Username "stockflow_runtime" -Password "UseVeryStrongPassword_Runtime_Only!" -TrustServerCertificate -InputFile .\Scripts\03_runtime_tests.sql
USE [StockFlowDb];
GO

/* =========================================================
   Cleanup testowych obiektów, jeśli istnieją
   (na wypadek wcześniejszych prób uruchomionych z szerokimi prawami)
   ========================================================= */
IF OBJECT_ID(N'app.ShouldFail', N'U') IS NOT NULL
BEGIN
    DROP TABLE app.ShouldFail;
END
GO

IF OBJECT_ID(N'api.ShouldAlsoFail', N'P') IS NOT NULL
BEGIN
    DROP PROCEDURE api.ShouldAlsoFail;
END
GO

/* =========================================================
   Test 1 - INSERT
   ========================================================= */
PRINT 'Test 1: runtime powinien móc dodać rekord';
INSERT INTO app.Products (Sku, Name, QuantityOnHand, LastUpdatedUtc)
VALUES (N'STK-001', N'Keyboard', 15, SYSUTCDATETIME());
GO

/* =========================================================
   Test 2 - SELECT po INSERT
   ========================================================= */
PRINT 'Test 2: runtime powinien móc odczytać rekord';
SELECT Id,
       Sku,
       Name,
       QuantityOnHand,
       CONVERT(varchar(33), LastUpdatedUtc, 126) AS LastUpdatedUtcIso
FROM app.Products
WHERE Sku = N'STK-001';
GO

/* =========================================================
   Test 3 - UPDATE
   ========================================================= */
PRINT 'Test 3: runtime powinien móc zaktualizować rekord';
UPDATE app.Products
SET QuantityOnHand = 20,
    LastUpdatedUtc = SYSUTCDATETIME()
WHERE Sku = N'STK-001';
GO

/* =========================================================
   Test 4 - SELECT po UPDATE
   ========================================================= */
PRINT 'Test 4: runtime powinien móc odczytać rekord po aktualizacji';
SELECT Id,
       Sku,
       Name,
       QuantityOnHand,
       CONVERT(varchar(33), LastUpdatedUtc, 126) AS LastUpdatedUtcIso
FROM app.Products
WHERE Sku = N'STK-001';
GO

/* =========================================================
   Test 5 - DELETE
   ========================================================= */
PRINT 'Test 5: runtime powinien móc usunąć rekord';
DELETE FROM app.Products
WHERE Sku = N'STK-001';
GO

/* =========================================================
   Test 6 - CREATE TABLE ma się nie udać
   ========================================================= */
PRINT 'Test 6: runtime NIE powinien móc utworzyć tabeli';
BEGIN TRY
    EXEC('CREATE TABLE app.ShouldFail (Id int NOT NULL)');
    SELECT 'UWAGA: To nie powinno przejść';
END TRY
BEGIN CATCH
    SELECT 'OK - oczekiwany błąd: ' + ERROR_MESSAGE();
END CATCH;
GO

/* =========================================================
   Test 7 - CREATE PROCEDURE ma się nie udać
   ========================================================= */
PRINT 'Test 7: runtime NIE powinien móc utworzyć procedury';
BEGIN TRY
    EXEC('CREATE PROCEDURE api.ShouldAlsoFail AS BEGIN SELECT 1; END');
    SELECT 'UWAGA: To nie powinno przejść';
END TRY
BEGIN CATCH
    SELECT 'OK - oczekiwany błąd: ' + ERROR_MESSAGE();
END CATCH;
GO

/* =========================================================
   Test 8 - Weryfikacja, że obiekty nie powstały
   ========================================================= */
PRINT 'Test 8: weryfikacja, że runtime nie utworzył obiektów DDL';
SELECT OBJECT_ID(N'app.ShouldFail', N'U') AS ShouldFailTableId,
       OBJECT_ID(N'api.ShouldAlsoFail', N'P') AS ShouldAlsoFailProcId;
GO