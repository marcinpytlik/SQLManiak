/*
    Relacyjny Renesans — Temporal Tables
    Historia zmian zarządzana przez SQL Server.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


DROP TABLE IF EXISTS dbo.Employees;
GO
CREATE TABLE dbo.Employees
(
    EmployeeId int NOT NULL PRIMARY KEY,
    FullName nvarchar(200) NOT NULL,
    Salary decimal(12,2) NOT NULL,
    ValidFrom datetime2 GENERATED ALWAYS AS ROW START NOT NULL,
    ValidTo datetime2 GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME(ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.EmployeesHistory));
GO
INSERT dbo.Employees(EmployeeId, FullName, Salary) VALUES (1, N'Anna Nowak', 10000);
UPDATE dbo.Employees SET Salary = 12000 WHERE EmployeeId = 1;
SELECT * FROM dbo.Employees FOR SYSTEM_TIME ALL WHERE EmployeeId = 1 ORDER BY ValidFrom;
GO
