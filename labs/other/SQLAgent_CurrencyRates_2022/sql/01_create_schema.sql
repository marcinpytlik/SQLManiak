-- sql/01_create_schema.sql
SET NOCOUNT ON;
GO
IF SCHEMA_ID(N'dbo') IS NULL EXEC('CREATE SCHEMA dbo');
GO

IF OBJECT_ID(N'dbo.ExchangeRates', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ExchangeRates
    (
        table_id       char(1)           NOT NULL,      -- 'A','B','C'
        table_no       nvarchar(30)      NOT NULL,      -- np. '197/A/NBP/2025'
        effective_date date              NOT NULL,
        code           char(3)           NOT NULL,      -- ISO 4217
        currency       nvarchar(128)     NOT NULL,
        rate           decimal(18,6)     NOT NULL,      -- 'mid' (table A/B) lub 'bid/ask' (table C – tu nie używamy)
        insert_ts      datetime2(0)      NOT NULL
            CONSTRAINT DF_ExchangeRates_insert_ts DEFAULT (sysdatetime())
        CONSTRAINT PK_ExchangeRates PRIMARY KEY CLUSTERED (table_id, code, effective_date, table_no)
    );
END
GO

-- Przyspieszenie zapytań po dacie i kodzie
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ExchangeRates_DateCode' AND object_id = OBJECT_ID(N'dbo.ExchangeRates'))
    CREATE NONCLUSTERED INDEX IX_ExchangeRates_DateCode
        ON dbo.ExchangeRates(effective_date DESC, code ASC)
        INCLUDE (rate, table_id, table_no);
GO
