-- Module 4 Exercise 1

-- Task 1 - generate audited activity
USE salesapp1;

UPDATE HR.Employees SET mgrid = 3 WHERE empid = 9;

INSERT HR.Employees
(lastname, firstname, title, titleofcourtesy, birthdate, hiredate, address, city, region, postalcode, country, phone, mgrid)
SELECT lastname, firstname, title, titleofcourtesy, birthdate, hiredate, address, city, region, postalcode, country, phone, mgrid
FROM HR.Employees WHERE empid = 9;

EXECUTE AS USER = 'marketing_user'
UPDATE HR.Employees SET mgrid = 5 WHERE empid = 9;
REVERT
GO

-- Task 2 - review audit data
-- write a query using the sys.fn_get_audit_file system function to return all the 
-- audit data from files in D:\Labfiles\Lab04\Starter\Audit.
-- Filter the data so that only activity related to your current session is displayed.


