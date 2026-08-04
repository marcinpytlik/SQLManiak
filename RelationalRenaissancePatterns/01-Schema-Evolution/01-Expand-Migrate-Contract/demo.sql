/*
    Relacyjny Renesans
    Demo: Expand -> Migrate -> Contract
    SQL Server

    Scenariusz:
    - wersja V1 przechowuje cały adres w dbo.Customers.AddressText,
    - wersja V2 przechowuje adresy w dbo.CustomerAddresses,
    - przez okres przejściowy obie wersje aplikacji mogą działać równolegle,
    - po walidacji usuwamy starą kolumnę.

    UWAGA:
    Skrypt jest demonstracyjny. Uruchamiaj go w środowisku laboratoryjnym.
*/

USE master;
GO

IF DB_ID(N'RelationalRenaissanceSchemaEvolution') IS NOT NULL
BEGIN
    ALTER DATABASE RelationalRenaissanceSchemaEvolution
        SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

    DROP DATABASE RelationalRenaissanceSchemaEvolution;
END;
GO

CREATE DATABASE RelationalRenaissanceSchemaEvolution;
GO

ALTER DATABASE RelationalRenaissanceSchemaEvolution
    SET RECOVERY SIMPLE;
GO

USE RelationalRenaissanceSchemaEvolution;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================
   ETAP 0. MODEL POCZĄTKOWY — APLIKACJA V1
   ============================================================ */

CREATE TABLE dbo.Customers
(
    CustomerId      int IDENTITY(1,1) NOT NULL,
    CustomerName    nvarchar(200) NOT NULL,
    EmailAddress    nvarchar(320) NOT NULL,
    AddressText     nvarchar(500) NULL,
    CreatedAt       datetime2(0) NOT NULL
        CONSTRAINT DF_Customers_CreatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Customers
        PRIMARY KEY CLUSTERED (CustomerId),

    CONSTRAINT UQ_Customers_EmailAddress
        UNIQUE (EmailAddress)
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_Customer_Create_V1
    @CustomerName nvarchar(200),
    @EmailAddress nvarchar(320),
    @AddressText  nvarchar(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO dbo.Customers
    (
        CustomerName,
        EmailAddress,
        AddressText
    )
    VALUES
    (
        @CustomerName,
        @EmailAddress,
        @AddressText
    );

    SELECT
        CustomerId,
        CustomerName,
        EmailAddress,
        AddressText,
        CreatedAt
    FROM dbo.Customers
    WHERE CustomerId = CONVERT(int, SCOPE_IDENTITY());
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Customer_Get_V1
    @CustomerId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CustomerId,
        CustomerName,
        EmailAddress,
        AddressText,
        CreatedAt
    FROM dbo.Customers
    WHERE CustomerId = @CustomerId;
END;
GO

EXEC dbo.usp_Customer_Create_V1
    @CustomerName = N'Anna Nowak',
    @EmailAddress = N'anna.nowak@example.com',
    @AddressText  = N'ul. Długa 10, 00-001 Warszawa';

EXEC dbo.usp_Customer_Create_V1
    @CustomerName = N'Jan Kowalski',
    @EmailAddress = N'jan.kowalski@example.com',
    @AddressText  = N'ul. Krótka 5, 50-100 Wrocław';

EXEC dbo.usp_Customer_Create_V1
    @CustomerName = N'Maria Wiśniewska',
    @EmailAddress = N'maria.wisniewska@example.com',
    @AddressText  = NULL;
GO

SELECT N'ETAP 0 — dane aplikacji V1' AS DemoStep;

SELECT *
FROM dbo.Customers
ORDER BY CustomerId;
GO

/* ============================================================
   ETAP 1. EXPAND
   Dodajemy nową strukturę bez usuwania starej kolumny.
   ============================================================ */

CREATE TABLE dbo.CustomerAddresses
(
    CustomerAddressId bigint IDENTITY(1,1) NOT NULL,
    CustomerId        int NOT NULL,
    AddressType       varchar(20) NOT NULL,
    AddressLine1      nvarchar(200) NOT NULL,
    PostalCode        nvarchar(20) NULL,
    City              nvarchar(100) NULL,
    CountryCode       char(2) NOT NULL
        CONSTRAINT DF_CustomerAddresses_CountryCode DEFAULT ('PL'),
    IsPrimary         bit NOT NULL
        CONSTRAINT DF_CustomerAddresses_IsPrimary DEFAULT (0),
    MigratedFromV1    bit NOT NULL
        CONSTRAINT DF_CustomerAddresses_MigratedFromV1 DEFAULT (0),
    CreatedAt         datetime2(0) NOT NULL
        CONSTRAINT DF_CustomerAddresses_CreatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_CustomerAddresses
        PRIMARY KEY CLUSTERED (CustomerAddressId),

    CONSTRAINT FK_CustomerAddresses_Customers
        FOREIGN KEY (CustomerId)
        REFERENCES dbo.Customers(CustomerId),

    CONSTRAINT CK_CustomerAddresses_AddressType
        CHECK (AddressType IN ('Billing', 'Shipping', 'Other')),

    CONSTRAINT CK_CustomerAddresses_CountryCode
        CHECK (CountryCode LIKE '[A-Z][A-Z]')
);
GO

CREATE UNIQUE INDEX UX_CustomerAddresses_OnePrimaryAddress
    ON dbo.CustomerAddresses(CustomerId)
    WHERE IsPrimary = 1;
GO

CREATE INDEX IX_CustomerAddresses_CustomerId
    ON dbo.CustomerAddresses(CustomerId)
    INCLUDE
    (
        AddressType,
        AddressLine1,
        PostalCode,
        City,
        CountryCode,
        IsPrimary
    );
GO

/*
    Tabela sterująca migracją.
    Pozwala wznowić proces oraz obserwować postęp.
*/
CREATE TABLE dbo.SchemaMigrationState
(
    MigrationName        sysname NOT NULL,
    LastCustomerId       int NOT NULL,
    RowsMigrated         bigint NOT NULL,
    StartedAt            datetime2(0) NOT NULL,
    LastBatchAt          datetime2(0) NULL,
    CompletedAt          datetime2(0) NULL,

    CONSTRAINT PK_SchemaMigrationState
        PRIMARY KEY CLUSTERED (MigrationName)
);
GO

INSERT INTO dbo.SchemaMigrationState
(
    MigrationName,
    LastCustomerId,
    RowsMigrated,
    StartedAt
)
VALUES
(
    N'CustomerAddress_V1_To_V2',
    0,
    0,
    SYSUTCDATETIME()
);
GO

SELECT N'ETAP 1 — nowa struktura istnieje, stara nadal działa' AS DemoStep;

EXEC dbo.usp_Customer_Get_V1 @CustomerId = 1;
GO

/* ============================================================
   ETAP 2. MIGRATE
   Migracja danych partiami.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_MigrateCustomerAddressesBatch
    @BatchSize int = 1000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @BatchSize < 1
    BEGIN
        THROW 50001, 'BatchSize musi być większy od zera.', 1;
    END;

    DECLARE
        @MigrationName  sysname = N'CustomerAddress_V1_To_V2',
        @LastCustomerId int,
        @RowsInserted   int,
        @NewLastId      int;

    SELECT
        @LastCustomerId = LastCustomerId
    FROM dbo.SchemaMigrationState WITH (UPDLOCK, HOLDLOCK)
    WHERE MigrationName = @MigrationName;

    IF @LastCustomerId IS NULL
    BEGIN
        THROW 50002, 'Brak wpisu sterującego migracją.', 1;
    END;

    BEGIN TRANSACTION;

    CREATE TABLE #Batch
    (
        CustomerId  int NOT NULL PRIMARY KEY,
        AddressText nvarchar(500) NOT NULL
    );

    INSERT INTO #Batch
    (
        CustomerId,
        AddressText
    )
    SELECT TOP (@BatchSize)
        c.CustomerId,
        c.AddressText
    FROM dbo.Customers AS c WITH (READPAST)
    WHERE c.CustomerId > @LastCustomerId
      AND c.AddressText IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.CustomerAddresses AS ca
          WHERE ca.CustomerId = c.CustomerId
            AND ca.MigratedFromV1 = 1
      )
    ORDER BY c.CustomerId;

    INSERT INTO dbo.CustomerAddresses
    (
        CustomerId,
        AddressType,
        AddressLine1,
        PostalCode,
        City,
        CountryCode,
        IsPrimary,
        MigratedFromV1
    )
    SELECT
        b.CustomerId,
        'Other',
        b.AddressText,
        NULL,
        NULL,
        'PL',
        1,
        1
    FROM #Batch AS b;

    SET @RowsInserted = @@ROWCOUNT;

    SELECT
        @NewLastId = MAX(CustomerId)
    FROM #Batch;

    IF @NewLastId IS NOT NULL
    BEGIN
        UPDATE dbo.SchemaMigrationState
        SET
            LastCustomerId = @NewLastId,
            RowsMigrated   = RowsMigrated + @RowsInserted,
            LastBatchAt    = SYSUTCDATETIME()
        WHERE MigrationName = @MigrationName;
    END
    ELSE
    BEGIN
        UPDATE dbo.SchemaMigrationState
        SET
            LastBatchAt = SYSUTCDATETIME(),
            CompletedAt = COALESCE(CompletedAt, SYSUTCDATETIME())
        WHERE MigrationName = @MigrationName;
    END;

    COMMIT TRANSACTION;

    SELECT
        @RowsInserted AS RowsInserted,
        @NewLastId AS LastCustomerIdInBatch;
END;
GO

/*
    W demie używamy małej partii, aby pokazać kolejne iteracje.
*/
EXEC dbo.usp_MigrateCustomerAddressesBatch @BatchSize = 1;
EXEC dbo.usp_MigrateCustomerAddressesBatch @BatchSize = 1;
EXEC dbo.usp_MigrateCustomerAddressesBatch @BatchSize = 1;
GO

SELECT N'ETAP 2 — wynik migracji danych' AS DemoStep;

SELECT *
FROM dbo.SchemaMigrationState;

SELECT *
FROM dbo.CustomerAddresses
ORDER BY CustomerAddressId;
GO

/* ============================================================
   ETAP 3. OKRES ZGODNOŚCI
   Aplikacja V1 nadal działa.
   Aplikacja V2 korzysta już z nowego modelu.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_Customer_Create_V2
    @CustomerName nvarchar(200),
    @EmailAddress nvarchar(320),
    @AddressType  varchar(20),
    @AddressLine1 nvarchar(200),
    @PostalCode   nvarchar(20) = NULL,
    @City         nvarchar(100) = NULL,
    @CountryCode  char(2) = 'PL'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CustomerId int;

    BEGIN TRANSACTION;

    INSERT INTO dbo.Customers
    (
        CustomerName,
        EmailAddress,
        AddressText
    )
    VALUES
    (
        @CustomerName,
        @EmailAddress,

        /*
            Dual write w okresie przejściowym:
            stara aplikacja nadal zobaczy uproszczony adres.
            W prawdziwym systemie wartość można budować dokładniej.
        */
        CONCAT(
            @AddressLine1,
            CASE
                WHEN @PostalCode IS NOT NULL OR @City IS NOT NULL
                THEN N', '
                ELSE N''
            END,
            COALESCE(@PostalCode + N' ', N''),
            COALESCE(@City, N'')
        )
    );

    SET @CustomerId = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO dbo.CustomerAddresses
    (
        CustomerId,
        AddressType,
        AddressLine1,
        PostalCode,
        City,
        CountryCode,
        IsPrimary,
        MigratedFromV1
    )
    VALUES
    (
        @CustomerId,
        @AddressType,
        @AddressLine1,
        @PostalCode,
        @City,
        @CountryCode,
        1,
        0
    );

    COMMIT TRANSACTION;

    SELECT @CustomerId AS CustomerId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Customer_Get_V2
    @CustomerId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.CustomerId,
        c.CustomerName,
        c.EmailAddress,
        c.CreatedAt,
        ca.CustomerAddressId,
        ca.AddressType,
        ca.AddressLine1,
        ca.PostalCode,
        ca.City,
        ca.CountryCode,
        ca.IsPrimary
    FROM dbo.Customers AS c
    LEFT JOIN dbo.CustomerAddresses AS ca
        ON ca.CustomerId = c.CustomerId
    WHERE c.CustomerId = @CustomerId
    ORDER BY
        ca.IsPrimary DESC,
        ca.CustomerAddressId;
END;
GO

/*
    Widok zgodności dla raportów oczekujących starego formatu.
*/
CREATE OR ALTER VIEW dbo.vw_Customers_Legacy
AS
    SELECT
        c.CustomerId,
        c.CustomerName,
        c.EmailAddress,
        COALESCE
        (
            c.AddressText,
            CONCAT
            (
                ca.AddressLine1,
                CASE
                    WHEN ca.PostalCode IS NOT NULL OR ca.City IS NOT NULL
                    THEN N', '
                    ELSE N''
                END,
                COALESCE(ca.PostalCode + N' ', N''),
                COALESCE(ca.City, N'')
            )
        ) AS AddressText,
        c.CreatedAt
    FROM dbo.Customers AS c
    OUTER APPLY
    (
        SELECT TOP (1)
            a.AddressLine1,
            a.PostalCode,
            a.City
        FROM dbo.CustomerAddresses AS a
        WHERE a.CustomerId = c.CustomerId
        ORDER BY
            a.IsPrimary DESC,
            a.CustomerAddressId
    ) AS ca;
GO

EXEC dbo.usp_Customer_Create_V2
    @CustomerName = N'Piotr Zieliński',
    @EmailAddress = N'piotr.zielinski@example.com',
    @AddressType  = 'Shipping',
    @AddressLine1 = N'ul. Leśna 15',
    @PostalCode   = N'30-001',
    @City         = N'Kraków',
    @CountryCode  = 'PL';
GO

SELECT N'ETAP 3A — odczyt aplikacji V1' AS DemoStep;
EXEC dbo.usp_Customer_Get_V1 @CustomerId = 4;

SELECT N'ETAP 3B — odczyt aplikacji V2' AS DemoStep;
EXEC dbo.usp_Customer_Get_V2 @CustomerId = 4;

SELECT N'ETAP 3C — raport korzystający z widoku zgodności' AS DemoStep;
SELECT *
FROM dbo.vw_Customers_Legacy
ORDER BY CustomerId;
GO

/* ============================================================
   ETAP 4. WALIDACJA PRZED CONTRACT
   Nie usuwamy starej struktury bez dowodów.
   ============================================================ */

SELECT N'ETAP 4A — klienci ze starym adresem bez rekordu V2' AS Validation;

SELECT
    c.CustomerId,
    c.CustomerName,
    c.AddressText
FROM dbo.Customers AS c
WHERE c.AddressText IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.CustomerAddresses AS ca
      WHERE ca.CustomerId = c.CustomerId
  );
GO

SELECT N'ETAP 4B — liczby kontrolne' AS Validation;

SELECT
    CustomersWithLegacyAddress =
    (
        SELECT COUNT_BIG(*)
        FROM dbo.Customers
        WHERE AddressText IS NOT NULL
    ),
    CustomersWithNewAddress =
    (
        SELECT COUNT_BIG(DISTINCT CustomerId)
        FROM dbo.CustomerAddresses
    ),
    MissingInNewModel =
    (
        SELECT COUNT_BIG(*)
        FROM dbo.Customers AS c
        WHERE c.AddressText IS NOT NULL
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.CustomerAddresses AS ca
              WHERE ca.CustomerId = c.CustomerId
          )
    );
GO

/*
    Kontrola zależności przed usunięciem kolumny.
    W środowisku produkcyjnym należy dodatkowo sprawdzić:
    - kod aplikacji,
    - procedury i funkcje,
    - raporty,
    - ETL,
    - integracje,
    - zapytania ad hoc,
    - Query Store / Extended Events.
*/
SELECT
    ReferencingSchema = OBJECT_SCHEMA_NAME(d.referencing_id),
    ReferencingObject = OBJECT_NAME(d.referencing_id),
    ReferencedEntity  = d.referenced_entity_name
FROM sys.sql_expression_dependencies AS d
WHERE d.referenced_id = OBJECT_ID(N'dbo.Customers')
ORDER BY
    ReferencingSchema,
    ReferencingObject;
GO

/* ============================================================
   ETAP 5. CONTRACT
   Wykonuj dopiero po wyłączeniu aplikacji V1 i starych zależności.
   ============================================================ */

/*
    Najpierw usuwamy obiekty, które bezpośrednio zależą od AddressText.
*/
DROP PROCEDURE IF EXISTS dbo.usp_Customer_Create_V1;
DROP PROCEDURE IF EXISTS dbo.usp_Customer_Get_V1;
DROP VIEW IF EXISTS dbo.vw_Customers_Legacy;
GO

/*
    Procedura V2 nie wykonuje już dual write do starej kolumny.
*/
CREATE OR ALTER PROCEDURE dbo.usp_Customer_Create_V2
    @CustomerName nvarchar(200),
    @EmailAddress nvarchar(320),
    @AddressType  varchar(20),
    @AddressLine1 nvarchar(200),
    @PostalCode   nvarchar(20) = NULL,
    @City         nvarchar(100) = NULL,
    @CountryCode  char(2) = 'PL'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CustomerId int;

    BEGIN TRANSACTION;

    INSERT INTO dbo.Customers
    (
        CustomerName,
        EmailAddress
    )
    VALUES
    (
        @CustomerName,
        @EmailAddress
    );

    SET @CustomerId = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO dbo.CustomerAddresses
    (
        CustomerId,
        AddressType,
        AddressLine1,
        PostalCode,
        City,
        CountryCode,
        IsPrimary,
        MigratedFromV1
    )
    VALUES
    (
        @CustomerId,
        @AddressType,
        @AddressLine1,
        @PostalCode,
        @City,
        @CountryCode,
        1,
        0
    );

    COMMIT TRANSACTION;

    SELECT @CustomerId AS CustomerId;
END;
GO

ALTER TABLE dbo.Customers
    DROP COLUMN AddressText;
GO

SELECT N'ETAP 5 — model końcowy po CONTRACT' AS DemoStep;

SELECT
    c.CustomerId,
    c.CustomerName,
    c.EmailAddress,
    c.CreatedAt,
    ca.CustomerAddressId,
    ca.AddressType,
    ca.AddressLine1,
    ca.PostalCode,
    ca.City,
    ca.CountryCode,
    ca.IsPrimary
FROM dbo.Customers AS c
LEFT JOIN dbo.CustomerAddresses AS ca
    ON ca.CustomerId = c.CustomerId
ORDER BY
    c.CustomerId,
    ca.IsPrimary DESC,
    ca.CustomerAddressId;
GO

/* ============================================================
   ETAP 6. TEST MODELU KOŃCOWEGO
   ============================================================ */

EXEC dbo.usp_Customer_Create_V2
    @CustomerName = N'Katarzyna Lewandowska',
    @EmailAddress = N'katarzyna.lewandowska@example.com',
    @AddressType  = 'Billing',
    @AddressLine1 = N'ul. Słoneczna 7',
    @PostalCode   = N'80-001',
    @City         = N'Gdańsk',
    @CountryCode  = 'PL';
GO

DECLARE @NewestCustomerId int =
(
    SELECT MAX(CustomerId)
    FROM dbo.Customers
);

EXEC dbo.usp_Customer_Get_V2
    @CustomerId = @NewestCustomerId;
GO

/* ============================================================
   PODSUMOWANIE
   ============================================================ */

SELECT
    StepNumber = 1,
    StepName   = N'EXPAND',
    Description = N'Dodanie nowej tabeli bez usuwania starej kolumny'
UNION ALL
SELECT
    2,
    N'MIGRATE',
    N'Przeniesienie danych małymi, wznawialnymi partiami'
UNION ALL
SELECT
    3,
    N'COMPATIBILITY',
    N'Czasowe utrzymanie obsługi aplikacji V1 i V2'
UNION ALL
SELECT
    4,
    N'VALIDATE',
    N'Kontrola kompletności danych i zależności'
UNION ALL
SELECT
    5,
    N'CONTRACT',
    N'Usunięcie starego kodu i kolumny dopiero po walidacji';
GO
