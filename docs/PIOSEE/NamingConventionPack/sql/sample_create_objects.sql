-- Przykładowe obiekty pod konwencję
CREATE SCHEMA app AUTHORIZATION dbo;
CREATE SCHEMA ref AUTHORIZATION dbo;
GO

IF OBJECT_ID('ref.Customer') IS NULL
BEGIN
    CREATE TABLE ref.Customer
    (
        Id         bigint        NOT NULL,
        Name       varchar(200)  NOT NULL,
        CreatedAt  datetime2(0)  NOT NULL CONSTRAINT DF_ref_Customer_CreatedAt DEFAULT (sysutcdatetime()),
        CONSTRAINT PK_ref_Customer PRIMARY KEY CLUSTERED (Id)
    );
END
GO

IF OBJECT_ID('app.[Order]') IS NULL
BEGIN
    CREATE TABLE app.[Order]
    (
        Id           bigint        NOT NULL,
        CustomerId   bigint        NOT NULL,
        OrderDate    datetime2(0)  NOT NULL,
        Amount       decimal(18,2) NOT NULL,
        Status       varchar(16)   NOT NULL CONSTRAINT DF_app_Order_Status DEFAULT ('New'),
        CreatedAt    datetime2(0)  NOT NULL CONSTRAINT DF_app_Order_CreatedAt DEFAULT (sysutcdatetime()),
        CONSTRAINT PK_app_Order PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_app_Order__ref_Customer FOREIGN KEY (CustomerId)
            REFERENCES ref.Customer (Id),
        CONSTRAINT CK_app_Order_Amount_gt0 CHECK (Amount > 0)
    );
    CREATE INDEX IX_app_Order_OrderDate_INC_CustomerId
        ON app.[Order] (OrderDate) INCLUDE (CustomerId);
END
GO

CREATE OR ALTER VIEW app.vw_OrderSummary AS
SELECT o.Id, o.OrderDate, o.Amount, c.Name AS CustomerName
FROM app.[Order] o
JOIN ref.Customer c ON c.Id = o.CustomerId;
GO

CREATE OR ALTER PROCEDURE app.usp_OrderUpsert
    @p_OrderId bigint,
    @p_Status  varchar(16)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE app.[Order] SET Status = @p_Status WHERE Id = @p_OrderId;
END
GO
