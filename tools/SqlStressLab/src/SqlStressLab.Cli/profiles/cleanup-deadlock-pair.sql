SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.DeadlockDemoA', N'U') IS NOT NULL
BEGIN
    UPDATE dbo.DeadlockDemoA
    SET CounterValue = 0,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = 1;
END;

IF OBJECT_ID(N'dbo.DeadlockDemoB', N'U') IS NOT NULL
BEGIN
    UPDATE dbo.DeadlockDemoB
    SET CounterValue = 0,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = 1;
END;
GO