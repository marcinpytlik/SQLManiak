/* TEST 08 - Ordering / duplicate delivery characteristics */
USE CDC_Lab;
GO

DECLARE @CustomerId int;

INSERT dbo.Customer (FirstName, LastName, Email)
VALUES ('Ordering','Test','ordering.0@test.local');

SET @CustomerId = SCOPE_IDENTITY();

UPDATE dbo.Customer
SET Email = 'ordering.1@test.local', ModifiedDate = SYSUTCDATETIME()
WHERE CustomerId = @CustomerId;

UPDATE dbo.Customer
SET Email = 'ordering.2@test.local', ModifiedDate = SYSUTCDATETIME()
WHERE CustomerId = @CustomerId;

UPDATE dbo.Customer
SET Email = 'ordering.3@test.local', ModifiedDate = SYSUTCDATETIME()
WHERE CustomerId = @CustomerId;

SELECT @CustomerId AS TestCustomerId;
GO

WAITFOR DELAY '00:00:05';
GO

SELECT TOP (50)
    __$start_lsn,
    __$seqval,
    __$operation,
    CustomerId,
    Email
FROM cdc.dbo_Customer_CT
WHERE FirstName = 'Ordering'
  AND LastName = 'Test'
ORDER BY __$start_lsn, __$seqval;
GO

/*
Consumer-side procedure:
1. Run the Kafka consumer and identify the CustomerId returned above.
2. Verify the logical order: INSERT -> update .1 -> update .2 -> update .3.
3. Restart Debezium Connect during/after consumption and observe whether any message is re-delivered.
4. Treat Kafka/Debezium delivery as at-least-once from the consumer design perspective: downstream should be idempotent.

PASS:
- events for the same key are observed in the expected logical order,
- any duplicate/re-delivered event can be detected and handled safely by the consumer,
- no committed business change is silently lost.
*/
