USE AdventureWorks
GO

UPDATE HumanResources.Employee
SET VacationHours = VacationHours + 10
WHERE SickLeaveHours < 30;