USE DemoVersioning;
GO
SET TRANSACTION ISOLATION LEVEL READ COMMITTED; -- RCSI przejmie sterowanie
GO
-- Uruchom i trzymaj to zapytanie podczas DELETE w innym oknie
SELECT COUNT(*) AS rcsi_visible_rows
FROM dbo.T WITH (READCOMMITTED);
