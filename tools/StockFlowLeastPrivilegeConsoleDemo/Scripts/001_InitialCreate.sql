IF OBJECT_ID(N'[app].[__EFMigrationsHistory]') IS NULL
BEGIN
    IF SCHEMA_ID(N'app') IS NULL EXEC(N'CREATE SCHEMA [app];');
    CREATE TABLE [app].[__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
IF SCHEMA_ID(N'app') IS NULL EXEC(N'CREATE SCHEMA [app];');

CREATE TABLE [app].[Products] (
    [Id] int NOT NULL IDENTITY,
    [Sku] nvarchar(50) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    [QuantityOnHand] int NOT NULL,
    [LastUpdatedUtc] datetime2 NOT NULL,
    CONSTRAINT [PK_Products] PRIMARY KEY ([Id])
);

CREATE UNIQUE INDEX [IX_Products_Sku] ON [app].[Products] ([Sku]);

INSERT INTO [app].[__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260410073813_InitialCreate', N'9.0.0');

COMMIT;
GO

