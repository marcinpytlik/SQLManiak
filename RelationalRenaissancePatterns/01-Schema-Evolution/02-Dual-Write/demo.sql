/*
    Relacyjny Renesans
    Demo: Dual Write — pomocny most czy źródło niespójności?

    Scenariusz:
      1. Model V1: dbo.Customers.AddressText
      2. Model V2: dbo.CustomerAddresses
      3. Naiwny Dual Write w dwóch niezależnych transakcjach
      4. Celowa awaria drugiego zapisu
      5. Niespójność danych
      6. Poprawny Dual Write w jednej transakcji
      7. Walidacja zgodności
      8. Jawne tryby: LegacyOnly / DualWrite / NewOnly

    UWAGA:
    Skrypt demonstracyjny. 
*/

USE master;
GO

IF DB_ID(N'RelationalRenaissanceDualWrite') IS NOT NULL
BEGIN
    ALTER DATABASE RelationalRenaissanceDualWrite
        SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

    DROP DATABASE RelationalRenaissanceDualWrite;
END;
GO

CREATE DATABASE RelationalRenaissanceDualWrite;
GO

ALTER DATABASE RelationalRenaissanceDualWrite
SET RECOVERY SIMPLE;
GO

USE RelationalRenaissanceDualWrite;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================
   ETAP 0. MODEL POCZĄTKOWY
   ============================================================ */

CREATE TABLE dbo.Customers
(
    CustomerId      int IDENTITY(1,1) NOT NULL,
    CustomerName    nvarchar(200) NOT NULL,
    EmailAddress    nvarchar(320) NOT NULL,
    AddressText     nvarchar(500) NULL,
    CreatedAt       datetime2(0) NOT NULL
        CONSTRAINT DF_Customers_CreatedAt
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Customers
        PRIMARY KEY CLUSTERED (CustomerId),

    CONSTRAINT UQ_Customers_Email
        UNIQUE (EmailAddress)
);
GO

CREATE TABLE dbo.CustomerAddresses
(
    CustomerAddressId bigint IDENTITY(1,1) NOT NULL,
    CustomerId        int NOT NULL,
    AddressType       varchar(20) NOT NULL,
    AddressLine1      nvarchar(200) NOT NULL,
    PostalCode        nvarchar(20) NULL,
    City              nvarchar(100) NULL,
    CountryCode       char(2) NOT NULL,
    IsPrimary         bit NOT NULL,
    CreatedAt         datetime2(0) NOT NULL
        CONSTRAINT DF_CustomerAddresses_CreatedAt
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_CustomerAddresses
        PRIMARY KEY CLUSTERED (CustomerAddressId),

    CONSTRAINT FK_CustomerAddresses_Customers
        FOREIGN KEY (CustomerId)
        REFERENCES dbo.Customers(CustomerId),

    CONSTRAINT CK_CustomerAddresses_AddressType
        CHECK (AddressType IN ('Billing','Shipping','Other')),

    CONSTRAINT CK_CustomerAddresses_CountryCode
        CHECK (CountryCode LIKE '[A-Z][A-Z]')
);
GO

CREATE UNIQUE INDEX UX_CustomerAddresses_Primary
ON dbo.CustomerAddresses(CustomerId)
WHERE IsPrimary = 1;
GO

INSERT INTO dbo.Customers
(
    CustomerName,
    EmailAddress,
    AddressText
)
VALUES
(
    N'Anna Nowak',
    N'anna.nowak@example.com',
    N'ul. Długa 10, 00-001 Warszawa'
);
GO

INSERT INTO dbo.CustomerAddresses
(
    CustomerId,
    AddressType,
    AddressLine1,
    PostalCode,
    City,
    CountryCode,
    IsPrimary
)
VALUES
(
    1,
    'Shipping',
    N'ul. Długa 10',
    N'00-001',
    N'Warszawa',
    'PL',
    1
);
GO

SELECT N'ETAP 0 — stan początkowy' AS DemoStep;

SELECT *
FROM dbo.Customers;

SELECT *
FROM dbo.CustomerAddresses;
GO

/* ============================================================
   ETAP 1. NAIWNY DUAL WRITE
   Dwie osobne transakcje.
   Pierwszy zapis się powiedzie.
   Drugi celowo zakończy się błędem.
   ============================================================ */

SELECT N'ETAP 1 — naiwny Dual Write' AS DemoStep;
GO

BEGIN TRANSACTION;

UPDATE dbo.Customers
SET AddressText = N'ul. Nowa 20, 00-002 Warszawa'
WHERE CustomerId = 1;

COMMIT;
GO

/*
    Symulacja awarii drugiego zapisu.
    Podajemy niepoprawny CountryCode.
    CHECK constraint zakończy operację błędem.
*/
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.CustomerAddresses
    SET
        AddressLine1 = N'ul. Nowa 20',
        PostalCode   = N'00-002',
        City         = N'Warszawa',
        CountryCode  = 'P1'
    WHERE CustomerId = 1
      AND IsPrimary = 1;

    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK;

    SELECT
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
GO

SELECT N'ETAP 1 — po awarii: modele są niespójne' AS DemoStep;

SELECT
    c.CustomerId,
    LegacyAddress = c.AddressText,
    NewAddress = CONCAT(
        ca.AddressLine1,
        N', ',
        ca.PostalCode,
        N' ',
        ca.City
    ),
    ca.CountryCode
FROM dbo.Customers AS c
JOIN dbo.CustomerAddresses AS ca
    ON ca.CustomerId = c.CustomerId
   AND ca.IsPrimary = 1;
GO

/* ============================================================
   ETAP 2. PRZYWRÓCENIE SPÓJNEGO STANU
   ============================================================ */

UPDATE dbo.Customers
SET AddressText = N'ul. Długa 10, 00-001 Warszawa'
WHERE CustomerId = 1;
GO

/* ============================================================
   ETAP 3. POPRAWNY DUAL WRITE — JEDNA TRANSAKCJA
   Drugi zapis znów zakończy się błędem.
   Tym razem pierwszy zapis zostanie wycofany.
   ============================================================ */

SELECT N'ETAP 3 — poprawny Dual Write w jednej transakcji' AS DemoStep;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.Customers
    SET AddressText = N'ul. Nowa 20, 00-002 Warszawa'
    WHERE CustomerId = 1;

    UPDATE dbo.CustomerAddresses
    SET
        AddressLine1 = N'ul. Nowa 20',
        PostalCode   = N'00-002',
        City         = N'Warszawa',
        CountryCode  = 'P1'
    WHERE CustomerId = 1
      AND IsPrimary = 1;

    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK;

    SELECT
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
GO

SELECT N'ETAP 3 — po rollbacku oba modele nadal są zgodne' AS DemoStep;

SELECT
    c.CustomerId,
    LegacyAddress = c.AddressText,
    NewAddress = CONCAT(
        ca.AddressLine1,
        N', ',
        ca.PostalCode,
        N' ',
        ca.City
    ),
    ca.CountryCode
FROM dbo.Customers AS c
JOIN dbo.CustomerAddresses AS ca
    ON ca.CustomerId = c.CustomerId
   AND ca.IsPrimary = 1;
GO

/* ============================================================
   ETAP 4. POPRAWNA PROCEDURA DUAL WRITE
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_CustomerAddress_Save_DualWrite
    @CustomerId   int,
    @AddressType  varchar(20),
    @AddressLine1 nvarchar(200),
    @PostalCode   nvarchar(20),
    @City         nvarchar(100),
    @CountryCode  char(2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Customers
        SET AddressText =
            CONCAT(
                @AddressLine1,
                N', ',
                @PostalCode,
                N' ',
                @City
            )
        WHERE CustomerId = @CustomerId;

        IF @@ROWCOUNT = 0
            THROW 50001, 'Nie znaleziono klienta.', 1;

        UPDATE dbo.CustomerAddresses
        SET
            AddressType  = @AddressType,
            AddressLine1 = @AddressLine1,
            PostalCode   = @PostalCode,
            City         = @City,
            CountryCode  = @CountryCode
        WHERE CustomerId = @CustomerId
          AND IsPrimary = 1;

        IF @@ROWCOUNT = 0
        BEGIN
            INSERT INTO dbo.CustomerAddresses
            (
                CustomerId,
                AddressType,
                AddressLine1,
                PostalCode,
                City,
                CountryCode,
                IsPrimary
            )
            VALUES
            (
                @CustomerId,
                @AddressType,
                @AddressLine1,
                @PostalCode,
                @City,
                @CountryCode,
                1
            );
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;

        THROW;
    END CATCH;
END;
GO

EXEC dbo.usp_CustomerAddress_Save_DualWrite
    @CustomerId   = 1,
    @AddressType  = 'Shipping',
    @AddressLine1 = N'ul. Nowa 20',
    @PostalCode   = N'00-002',
    @City         = N'Warszawa',
    @CountryCode  = 'PL';
GO

SELECT N'ETAP 4 — poprawny zapis do obu modeli' AS DemoStep;

SELECT
    c.CustomerId,
    LegacyAddress = c.AddressText,
    NewAddress = CONCAT(
        ca.AddressLine1,
        N', ',
        ca.PostalCode,
        N' ',
        ca.City
    ),
    ca.CountryCode
FROM dbo.Customers AS c
JOIN dbo.CustomerAddresses AS ca
    ON ca.CustomerId = c.CustomerId
   AND ca.IsPrimary = 1;
GO

/* ============================================================
   ETAP 5. WALIDACJA ZGODNOŚCI
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_DualWriteConsistency
AS
    SELECT
        c.CustomerId,
        c.CustomerName,
        LegacyAddress = c.AddressText,
        NewAddress =
            CONCAT(
                ca.AddressLine1,
                N', ',
                ca.PostalCode,
                N' ',
                ca.City
            ),
        IsConsistent =
            CONVERT(
                bit,
                CASE
                    WHEN ISNULL(c.AddressText, N'') =
                         ISNULL(
                             CONCAT(
                                 ca.AddressLine1,
                                 N', ',
                                 ca.PostalCode,
                                 N' ',
                                 ca.City
                             ),
                             N''
                         )
                    THEN 1
                    ELSE 0
                END
            )
    FROM dbo.Customers AS c
    LEFT JOIN dbo.CustomerAddresses AS ca
        ON ca.CustomerId = c.CustomerId
       AND ca.IsPrimary = 1;
GO

SELECT N'ETAP 5 — raport zgodności' AS DemoStep;

SELECT *
FROM dbo.vw_DualWriteConsistency;
GO

SELECT
    InconsistentRows = COUNT_BIG(*)
FROM dbo.vw_DualWriteConsistency
WHERE IsConsistent = 0;
GO

/* ============================================================
   ETAP 6. JAWNE TRYBY MIGRACJI
   LegacyOnly / DualWrite / NewOnly
   ============================================================ */

CREATE TABLE dbo.SchemaWriteMode
(
    FeatureName sysname NOT NULL,
    WriteMode   varchar(20) NOT NULL,
    UpdatedAt   datetime2(0) NOT NULL
        CONSTRAINT DF_SchemaWriteMode_UpdatedAt
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_SchemaWriteMode
        PRIMARY KEY (FeatureName),

    CONSTRAINT CK_SchemaWriteMode_WriteMode
        CHECK (WriteMode IN ('LegacyOnly','DualWrite','NewOnly'))
);
GO

INSERT INTO dbo.SchemaWriteMode
(
    FeatureName,
    WriteMode
)
VALUES
(
    N'CustomerAddress',
    'DualWrite'
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_CustomerAddress_Save
    @CustomerId   int,
    @AddressType  varchar(20),
    @AddressLine1 nvarchar(200),
    @PostalCode   nvarchar(20),
    @City         nvarchar(100),
    @CountryCode  char(2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @WriteMode varchar(20);

    SELECT @WriteMode = WriteMode
    FROM dbo.SchemaWriteMode
    WHERE FeatureName = N'CustomerAddress';

    IF @WriteMode IS NULL
        THROW 50010, 'Brak konfiguracji trybu zapisu.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @WriteMode IN ('LegacyOnly','DualWrite')
        BEGIN
            UPDATE dbo.Customers
            SET AddressText =
                CONCAT(
                    @AddressLine1,
                    N', ',
                    @PostalCode,
                    N' ',
                    @City
                )
            WHERE CustomerId = @CustomerId;

            IF @@ROWCOUNT = 0
                THROW 50011, 'Nie znaleziono klienta.', 1;
        END;

        IF @WriteMode IN ('DualWrite','NewOnly')
        BEGIN
            /*
                Bez MERGE — jawny UPDATE + INSERT jest w demie
                łatwiejszy do wyjaśnienia i kontrolowania.
            */
            UPDATE dbo.CustomerAddresses
            SET
                AddressType  = @AddressType,
                AddressLine1 = @AddressLine1,
                PostalCode   = @PostalCode,
                City         = @City,
                CountryCode  = @CountryCode
            WHERE CustomerId = @CustomerId
              AND IsPrimary = 1;

            IF @@ROWCOUNT = 0
            BEGIN
                INSERT INTO dbo.CustomerAddresses
                (
                    CustomerId,
                    AddressType,
                    AddressLine1,
                    PostalCode,
                    City,
                    CountryCode,
                    IsPrimary
                )
                VALUES
                (
                    @CustomerId,
                    @AddressType,
                    @AddressLine1,
                    @PostalCode,
                    @City,
                    @CountryCode,
                    1
                );
            END;
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;

        THROW;
    END CATCH;
END;
GO

/* ============================================================
   ETAP 7. TEST TRYBU DUALWRITE
   ============================================================ */

SELECT N'ETAP 7 — tryb DualWrite' AS DemoStep;

EXEC dbo.usp_CustomerAddress_Save
    @CustomerId   = 1,
    @AddressType  = 'Shipping',
    @AddressLine1 = N'ul. Testowa 30',
    @PostalCode   = N'00-003',
    @City         = N'Warszawa',
    @CountryCode  = 'PL';
GO

SELECT *
FROM dbo.vw_DualWriteConsistency;
GO

/* ============================================================
   ETAP 8. PRZEŁĄCZENIE NA NEWONLY
   ============================================================ */

UPDATE dbo.SchemaWriteMode
SET
    WriteMode = 'NewOnly',
    UpdatedAt = SYSUTCDATETIME()
WHERE FeatureName = N'CustomerAddress';
GO

SELECT N'ETAP 8 — tryb NewOnly' AS DemoStep;

EXEC dbo.usp_CustomerAddress_Save
    @CustomerId   = 1,
    @AddressType  = 'Shipping',
    @AddressLine1 = N'ul. Docelowa 40',
    @PostalCode   = N'00-004',
    @City         = N'Warszawa',
    @CountryCode  = 'PL';
GO

SELECT
    c.CustomerId,
    c.AddressText AS LegacyAddress,
    CONCAT(
        ca.AddressLine1,
        N', ',
        ca.PostalCode,
        N' ',
        ca.City
    ) AS NewAddress
FROM dbo.Customers AS c
JOIN dbo.CustomerAddresses AS ca
    ON ca.CustomerId = c.CustomerId
   AND ca.IsPrimary = 1;
GO

/*
    Tutaj różnica jest już oczekiwana.

    Po przejściu na NewOnly stary model został zamrożony,
    więc raport zgodności z etapu DualWrite nie powinien
    być dalej interpretowany w ten sam sposób.

    Od tego momentu CustomerAddresses jest źródłem prawdy.
*/
GO

/* ============================================================
   ETAP 9. PODSUMOWANIE
   ============================================================ */

SELECT
    StepNumber = 1,
    StepName = N'Naive Dual Write',
    Description = N'Dwa niezależne zapisy mogą pozostawić niespójne dane'
UNION ALL
SELECT
    2,
    N'Atomic Dual Write',
    N'Jedna lokalna transakcja gwarantuje atomowość obu zapisów'
UNION ALL
SELECT
    3,
    N'Consistency Check',
    N'Modele trzeba regularnie porównywać podczas migracji'
UNION ALL
SELECT
    4,
    N'Explicit Write Mode',
    N'LegacyOnly, DualWrite i NewOnly opisują jawny etap migracji'
UNION ALL
SELECT
    5,
    N'NewOnly',
    N'Po przełączeniu nowy model staje się źródłem prawdy';
GO
