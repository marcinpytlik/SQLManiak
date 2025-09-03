--Module 10 Demo 4

USE TestAlertDB;
GO

SET NOCOUNT ON;
WHILE 1 = 1
BEGIN
   INSERT INTO testtable (col1)
   SELECT 'Test data!'
   UNION ALL SELECT col1 FROM testtable;
END;
GO