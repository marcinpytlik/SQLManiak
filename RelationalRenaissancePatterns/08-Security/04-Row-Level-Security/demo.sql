/*
    Relacyjny Renesans — Row-Level Security
    Filtrowanie wierszy według kontekstu sesji.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DROP SECURITY POLICY IF EXISTS dbo.SalesSecurityPolicy;
DROP FUNCTION IF EXISTS dbo.fn_SalesPredicate;
DROP TABLE IF EXISTS dbo.Sales;
GO
CREATE TABLE dbo.Sales
(
    SaleId int IDENTITY PRIMARY KEY,
    TenantId int NOT NULL,
    Amount decimal(12,2) NOT NULL
);
GO
CREATE FUNCTION dbo.fn_SalesPredicate(@TenantId int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS IsAllowed
    WHERE @TenantId = TRY_CONVERT(int, SESSION_CONTEXT(N'TenantId'))
);
GO
CREATE SECURITY POLICY dbo.SalesSecurityPolicy
ADD FILTER PREDICATE dbo.fn_SalesPredicate(TenantId) ON dbo.Sales
WITH (STATE = ON);
GO
