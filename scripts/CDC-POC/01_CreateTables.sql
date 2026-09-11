/* SQLManiak - CDC POC | 01_CreateTables.sql */
USE CDC_Lab;
GO

CREATE TABLE dbo.Customer
(
    CustomerId   int IDENTITY(1,1) NOT NULL,
    FirstName    varchar(100) NOT NULL,
    LastName     varchar(100) NOT NULL,
    Email        varchar(255) NULL,
    ModifiedDate datetime2(3) NOT NULL
        CONSTRAINT DF_Customer_ModifiedDate DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Customer PRIMARY KEY (CustomerId)
);
GO

CREATE TABLE dbo.CustomerOrder
(
    OrderId      bigint IDENTITY(1,1) NOT NULL,
    CustomerId   int NOT NULL,
    OrderDate    datetime2(3) NOT NULL
        CONSTRAINT DF_CustomerOrder_OrderDate DEFAULT SYSUTCDATETIME(),
    Amount       decimal(18,2) NOT NULL,
    Status       varchar(30) NOT NULL,
    CONSTRAINT PK_CustomerOrder PRIMARY KEY (OrderId),
    CONSTRAINT FK_CustomerOrder_Customer
        FOREIGN KEY (CustomerId) REFERENCES dbo.Customer(CustomerId)
);
GO
