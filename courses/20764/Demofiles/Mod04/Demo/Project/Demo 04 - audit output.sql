-- Module 4 - Demo 4

-- Step 1 - create an audit with a file target
USE master;
GO
CREATE SERVER AUDIT File_Audit 
    TO FILE (FILEPATH='D:\Demofiles\Mod04\Audit\')
    WITH (QUEUE_DELAY = 5000);
GO
ALTER SERVER AUDIT File_Audit WITH (STATE = ON);
GO

-- Step 2 - create an audit with a Windows application log target
CREATE SERVER AUDIT AppLog_Audit 
    TO APPLICATION_LOG
    WITH (QUEUE_DELAY = 5000);
GO
ALTER SERVER AUDIT AppLog_Audit WITH (STATE = ON);
GO

-- Step 3 - add the same database audit specification to both audits
USE salesapp1;
GO
CREATE DATABASE AUDIT SPECIFICATION sales_select_spec_file
FOR SERVER AUDIT File_Audit
ADD (SELECT ON SCHEMA::Sales BY public)
WITH (STATE = ON);
GO

CREATE DATABASE AUDIT SPECIFICATION sales_select_spec_applog
FOR SERVER AUDIT AppLog_Audit
ADD (SELECT ON SCHEMA::Sales BY public)
WITH (STATE = ON);
GO

-- Step 4 - execute a simple select statement which matches the audit specification
SELECT TOP 10 * FROM Sales.Customers;
GO

-- Step 5 - examine the file-based audit output
-- Demonstrate some of the most useful fields
SELECT *
FROM sys.fn_get_audit_file ('D:\Demofiles\Mod04\Audit\File_Audit*',default,default)

-- Step 6 - examin the Windows application log audit output
-- Use Event Viewer

-- Step 7 - drop audits and audit specifications
-- notice that the audits and specifications must be disabled before they can be dropped
USE salesapp1;
ALTER DATABASE AUDIT SPECIFICATION sales_select_spec_applog WITH (STATE = OFF);
DROP DATABASE AUDIT SPECIFICATION sales_select_spec_applog;
ALTER DATABASE AUDIT SPECIFICATION sales_select_spec_file WITH (STATE = OFF);
DROP DATABASE AUDIT SPECIFICATION sales_select_spec_file;
GO
USE master;
ALTER SERVER AUDIT AppLog_Audit WITH (STATE = OFF);
DROP SERVER AUDIT AppLog_Audit;
ALTER SERVER AUDIT File_Audit WITH (STATE = OFF);
DROP SERVER AUDIT File_Audit;
GO

