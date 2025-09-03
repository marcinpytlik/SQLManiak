-- Working with mismatched SIDs. 

-- STEP A. Check for orphaned users.
USE TSQL;
GO
EXEC sp_change_users_login 'Report';
GO

-- STEP B. Show that the appuser login exists, but with a different SID
SELECT name, SID from sys.server_principals WHERE name in ('appuser','reportuser');

-- STEP C. Repair the appuser1 orphaned user you found in the first task by linking it to the appuser login.
EXEC sp_change_users_login @Action = 'Update_One', @UserNamePattern = 'appuser1', @LoginName = 'appuser';

-- STEP D. Rerun the check for orphaned users
USE TSQL;
EXEC sp_change_users_login 'Report';
GO

-- STEP E. Repair the reportuser1 user by creating a login with a matching SID
CREATE LOGIN [reportuser] 
WITH	PASSWORD = 'Pa$$w0rd', SID=0x4489DB6EF75A26488BD427DFA24CA5EF;

-- STEP F. Rerun the check for orphaned users
USE TSQL;
EXEC sp_change_users_login 'Report';
GO

 