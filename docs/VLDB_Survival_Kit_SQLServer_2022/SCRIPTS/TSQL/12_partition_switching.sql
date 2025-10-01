/* 12_partition_switching.sql
Sliding window: split/merge + switch.
*/
USE VLDB;
GO
-- Przygotuj tabelę staging o identycznej definicji
IF OBJECT_ID('dbo.FactSale_Stage','U') IS NULL
BEGIN
    CREATE TABLE dbo.FactSale_Stage
    (
        SaleId     bigint NOT NULL,
        SaleDate   date   NOT NULL CHECK (SaleDate >= '2026-01-01' AND SaleDate < '2026-07-01'),
        CustomerId int    NOT NULL,
        Amount     money  NOT NULL,
        CONSTRAINT PK_FactSale_Stage PRIMARY KEY CLUSTERED (SaleDate, SaleId)
    ) ON ps_VLDB_Date(SaleDate);
END
GO
-- 1) SPLIT range dla nowej granicy
ALTER PARTITION FUNCTION pf_VLDB_Date() SPLIT RANGE ('2026-07-01');
-- 2) SWITCH z staging do produkcji (do właściwej partycji)
ALTER TABLE dbo.FactSale_Stage SWITCH TO dbo.FactSale PARTITION $PARTITION.pf_VLDB_Date('2026-01-02');
-- 3) MERGE najstarszego zakresu (przykładowo)
-- ALTER PARTITION FUNCTION pf_VLDB_Date() MERGE RANGE ('2024-01-01');
