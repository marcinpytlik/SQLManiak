USE [CDC_Lab];
GO

PRINT '1. INSERT';
INSERT dbo.Customer (FirstName, LastName, Email)
VALUES ('Debezium', 'InsertTest', 'insert@sqllab.local');
GO

DECLARE @CustomerId int =
(
    SELECT TOP (1) CustomerId
    FROM dbo.Customer
    WHERE LastName = 'InsertTest'
    ORDER BY CustomerId DESC
);

PRINT '2. UPDATE';
UPDATE dbo.Customer
SET Email = 'updated@sqllab.local',
    ModifiedDate = SYSUTCDATETIME()
WHERE CustomerId = @CustomerId;

PRINT '3. INSERT child row';
INSERT dbo.CustomerOrder (CustomerId, OrderDate, Amount, Status)
VALUES (@CustomerId, SYSUTCDATETIME(), 123.45, 'NEW');

PRINT '4. DELETE child row';
DELETE dbo.CustomerOrder
WHERE CustomerId = @CustomerId;

PRINT '5. DELETE parent row';
DELETE dbo.Customer
WHERE CustomerId = @CustomerId;
GO

/*
Expected Debezium operations:
  c = create/insert
  u = update
  d = delete
Snapshot rows, when present, use:
  r = read
*/
