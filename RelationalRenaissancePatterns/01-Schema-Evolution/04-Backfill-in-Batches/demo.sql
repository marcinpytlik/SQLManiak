/*
    Relacyjny Renesans — Backfill in Batches
    Migracja danych małymi partiami.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DROP TABLE IF EXISTS dbo.BackfillDemo;
GO
CREATE TABLE dbo.BackfillDemo
(
    Id int IDENTITY PRIMARY KEY,
    OldValue int NOT NULL,
    NewValue int NULL
);
GO
INSERT dbo.BackfillDemo(OldValue)
SELECT TOP (10000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
WHILE 1 = 1
BEGIN
    UPDATE TOP (500) dbo.BackfillDemo
    SET NewValue = OldValue * 10
    WHERE NewValue IS NULL;

    IF @@ROWCOUNT = 0 BREAK;
END;
GO
SELECT COUNT(*) AS MissingRows FROM dbo.BackfillDemo WHERE NewValue IS NULL;
GO
