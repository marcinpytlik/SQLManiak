
PRINT '--- Lab 3: Adaptive Join + Batch Mode on Rowstore ---';
SET NOCOUNT ON;
USE AQP_Lab;

DBCC FREEPROCCACHE WITH NO_INFOMSGS;
GO

-- Włącz wyświetlanie rzeczywistego planu wykonania w swoim kliencie, aby zobaczyć operator "Adaptive Join".
-- Zapytanie łączy tabelę sama z sobą po kolumnie o zmiennej selektywności.
SELECT s1.*
FROM dbo.Skew s1
JOIN dbo.Skew s2 ON s2.grp = s1.grp
WHERE s1.grp IN (1, 9999);

-- Wskazówka: w planie szukaj "Adaptive Join" (przełączanie NL/Hash po progu).
