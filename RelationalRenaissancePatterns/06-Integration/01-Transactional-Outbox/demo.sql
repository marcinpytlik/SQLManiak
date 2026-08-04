/*
    Relacyjny Renesans — Transactional Outbox
    Dane biznesowe i komunikat w jednej transakcji.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DROP TABLE IF EXISTS dbo.OutboxMessages;
DROP TABLE IF EXISTS dbo.Orders;
GO
CREATE TABLE dbo.Orders
(
    OrderId int IDENTITY PRIMARY KEY,
    CustomerId int NOT NULL,
    Amount decimal(12,2) NOT NULL
);
CREATE TABLE dbo.OutboxMessages
(
    MessageId uniqueidentifier NOT NULL PRIMARY KEY,
    MessageType nvarchar(200) NOT NULL,
    Payload nvarchar(max) NOT NULL,
    CreatedAt datetime2 NOT NULL,
    ProcessedAt datetime2 NULL
);
GO
BEGIN TRANSACTION;
DECLARE @OrderId int;
INSERT dbo.Orders(CustomerId, Amount) VALUES (1, 250.00);
SET @OrderId = SCOPE_IDENTITY();
INSERT dbo.OutboxMessages(MessageId, MessageType, Payload, CreatedAt)
VALUES (NEWID(), N'OrderCreated', CONCAT(N'{"orderId":', @OrderId, N'}'), SYSUTCDATETIME());
COMMIT;
GO
SELECT * FROM dbo.Orders;
SELECT * FROM dbo.OutboxMessages;
GO
