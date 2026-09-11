/* SQLManiak - CDC POC | 03_GenerateData.sql */
USE CDC_Lab;
GO

INSERT dbo.Customer (FirstName, LastName, Email)
VALUES
    ('Jan', 'Kowalski', 'jan.kowalski@example.com'),
    ('Anna', 'Nowak', 'anna.nowak@example.com'),
    ('Piotr', 'Zielinski', 'piotr.zielinski@example.com');
GO

INSERT dbo.CustomerOrder (CustomerId, Amount, Status)
SELECT CustomerId, 199.99, 'NEW'
FROM dbo.Customer
WHERE Email = 'jan.kowalski@example.com';

INSERT dbo.CustomerOrder (CustomerId, Amount, Status)
SELECT CustomerId, 499.00, 'NEW'
FROM dbo.Customer
WHERE Email = 'anna.nowak@example.com';
GO

UPDATE dbo.Customer
SET Email = 'jan.kowalski.changed@example.com',
    ModifiedDate = SYSUTCDATETIME()
WHERE Email = 'jan.kowalski@example.com';
GO

UPDATE dbo.CustomerOrder
SET Status = 'PAID'
WHERE Status = 'NEW';
GO

DELETE dbo.CustomerOrder
WHERE CustomerId = (SELECT CustomerId FROM dbo.Customer WHERE Email = 'piotr.zielinski@example.com');

DELETE dbo.Customer
WHERE Email = 'piotr.zielinski@example.com';
GO

SELECT * FROM dbo.Customer ORDER BY CustomerId;
SELECT * FROM dbo.CustomerOrder ORDER BY OrderId;
GO
