/* TEST 05 - Rollback should not create committed CDC events */
USE CDC_Lab;
GO

DECLARE @Before bigint =
(
    SELECT COUNT_BIG(*)
    FROM cdc.dbo_Customer_CT
    WHERE LastName = 'RollbackTest'
);

BEGIN TRAN;

INSERT dbo.Customer (FirstName, LastName, Email)
VALUES ('CDC','RollbackTest','rollback@test.local');

UPDATE dbo.Customer
SET Email = 'rollback.changed@test.local',
    ModifiedDate = SYSUTCDATETIME()
WHERE LastName = 'RollbackTest';

ROLLBACK TRAN;
GO

WAITFOR DELAY '00:00:05';
GO

SELECT *
FROM dbo.Customer
WHERE LastName = 'RollbackTest';
GO

SELECT *
FROM cdc.dbo_Customer_CT
WHERE LastName = 'RollbackTest';
GO

/*
PASS:
- no row remains in dbo.Customer,
- no committed business change for RollbackTest appears in cdc.dbo_Customer_CT,
- no corresponding Debezium business event is emitted.
*/
