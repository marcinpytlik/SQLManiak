/*
    Relacyjny Renesans — Soft Delete with Filtered Unique Index
    Unikalność wyłącznie dla aktywnych rekordów.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DROP TABLE IF EXISTS dbo.Users;
GO
CREATE TABLE dbo.Users
(
    UserId int IDENTITY PRIMARY KEY,
    Email nvarchar(320) NOT NULL,
    IsDeleted bit NOT NULL CONSTRAINT DF_Users_IsDeleted DEFAULT 0
);
GO
CREATE UNIQUE INDEX UX_Users_Email_Active
ON dbo.Users(Email)
WHERE IsDeleted = 0;
GO
INSERT dbo.Users(Email) VALUES (N'user@example.com');
UPDATE dbo.Users SET IsDeleted = 1 WHERE Email = N'user@example.com';
INSERT dbo.Users(Email) VALUES (N'user@example.com');
SELECT * FROM dbo.Users;
GO
