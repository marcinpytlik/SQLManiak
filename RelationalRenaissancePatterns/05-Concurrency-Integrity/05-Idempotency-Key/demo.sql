/*
    Relacyjny Renesans — Idempotency Key
    Ochrona przed podwójnym wykonaniem żądania.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DROP TABLE IF EXISTS dbo.Payments;
GO
CREATE TABLE dbo.Payments
(
    PaymentId bigint IDENTITY PRIMARY KEY,
    IdempotencyKey uniqueidentifier NOT NULL,
    Amount decimal(12,2) NOT NULL,
    CreatedAt datetime2 NOT NULL CONSTRAINT DF_Payments_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Payments_IdempotencyKey UNIQUE(IdempotencyKey)
);
GO
DECLARE @Key uniqueidentifier = NEWID();
INSERT dbo.Payments(IdempotencyKey, Amount) VALUES (@Key, 100.00);
-- Ponowne wykonanie z tym samym kluczem zostanie zatrzymane przez UNIQUE.
SELECT * FROM dbo.Payments;
GO
