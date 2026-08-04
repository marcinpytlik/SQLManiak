/*
    Relacyjny Renesans — Filtered Index
    Indeks obejmujący tylko aktywne rekordy.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DROP TABLE IF EXISTS dbo.Tasks;
GO
CREATE TABLE dbo.Tasks
(
    TaskId bigint IDENTITY PRIMARY KEY,
    Status varchar(20) NOT NULL,
    CreatedAt datetime2 NOT NULL
);
GO
CREATE INDEX IX_Tasks_Open
ON dbo.Tasks(CreatedAt)
WHERE Status = 'Open';
GO
