/*
    Relacyjny Renesans — Shadow Column
    Bezpieczna zmiana typu kolumny.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DROP TABLE IF EXISTS dbo.Documents;
GO
CREATE TABLE dbo.Documents
(
    DocumentId int IDENTITY PRIMARY KEY,
    DocumentNumber int NOT NULL,
    DocumentNumberV2 varchar(30) NULL
);
GO
INSERT dbo.Documents(DocumentNumber) VALUES (1001),(1002),(1003);
GO
UPDATE dbo.Documents
SET DocumentNumberV2 = CONVERT(varchar(30), DocumentNumber)
WHERE DocumentNumberV2 IS NULL;
GO
SELECT * FROM dbo.Documents;
GO
