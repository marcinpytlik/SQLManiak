/*
    Relacyjny Renesans — Keyset Pagination
    Stronicowanie na podstawie ostatniego klucza.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DROP TABLE IF EXISTS dbo.Posts;
GO
CREATE TABLE dbo.Posts
(
    PostId bigint IDENTITY PRIMARY KEY,
    CreatedAt datetime2 NOT NULL,
    Title nvarchar(200) NOT NULL
);
GO
INSERT dbo.Posts(CreatedAt, Title)
SELECT TOP (1000)
    DATEADD(second, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), '2026-01-01'),
    CONCAT(N'Post ', ROW_NUMBER() OVER (ORDER BY (SELECT NULL)))
FROM sys.all_objects;
GO
DECLARE @LastCreatedAt datetime2 = '2026-01-01';
DECLARE @LastPostId bigint = 0;

SELECT TOP (20) *
FROM dbo.Posts
WHERE (CreatedAt > @LastCreatedAt)
   OR (CreatedAt = @LastCreatedAt AND PostId > @LastPostId)
ORDER BY CreatedAt, PostId;
GO
