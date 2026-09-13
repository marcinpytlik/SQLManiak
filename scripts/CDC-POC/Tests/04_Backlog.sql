/* TEST 04 - Backlog recovery */
USE CDC_Lab;
GO

DECLARE @Rows int = 10000;

;WITH n AS
(
    SELECT TOP (@Rows)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT dbo.Customer (FirstName, LastName, Email)
SELECT
    'Backlog',
    CONCAT('Row', rn),
    CONCAT('backlog', rn, '@test.local')
FROM n;
GO

SELECT COUNT(*) AS SourceRows
FROM dbo.Customer
WHERE FirstName = 'Backlog';
GO

WAITFOR DELAY '00:00:05';
GO

SELECT COUNT(*) AS CdcRows
FROM cdc.dbo_Customer_CT
WHERE FirstName = 'Backlog';
GO

/*
Procedure:
1. Stop sqllab-debezium-connect before running this script.
2. Execute this script.
3. Confirm rows exist in cdc.dbo_Customer_CT.
4. Start Debezium Connect.
5. Measure how long it takes to drain the backlog.

PASS:
- all 10,000 INSERT events are eventually delivered downstream,
- connector/task returns to RUNNING,
- no CDC error is recorded.
*/
