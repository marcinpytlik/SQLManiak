SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.BlockingDemo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BlockingDemo
    (
        Id           int          NOT NULL CONSTRAINT PK_BlockingDemo PRIMARY KEY,
        CounterValue int          NOT NULL,
        UpdatedAt    datetime2(3) NOT NULL
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.BlockingDemo
    WHERE Id = 1
)
BEGIN
    INSERT INTO dbo.BlockingDemo (Id, CounterValue, UpdatedAt)
    VALUES (1, 0, SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE dbo.BlockingDemo
    SET CounterValue = 0,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_BlockingDemo
    @Id int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    UPDATE dbo.BlockingDemo
    SET CounterValue = CounterValue + 1,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @Id;

    WAITFOR DELAY '00:00:02';

    COMMIT TRAN;
END;
GO