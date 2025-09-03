---------------------------------------------------------------------
-- LAB 03
--
-- Exercise 3
---------------------------------------------------------------------

USE TSQL;
GO

---------------------------------------------------------------------
-- Task 1
-- 
--
-- Run a check for orphaned users in the newly restored TSQL database. 
-- Hint: use sp_change_users_login with the @Action parameter set to 'Report'.
---------------------------------------------------------------------
EXEC sp_change_users_login @Action = 'Report'

---------------------------------------------------------------------
-- Task 2
-- 
--
-- Repair the orphaned user you found in the first task by linking it to the appuser login.
---------------------------------------------------------------------
EXEC sp_change_users_login @Action = 'Update_One', @UserNamePattern = 'appuser1', @LoginName = 'appuser';

---------------------------------------------------------------------
-- Task 3
-- 
--
-- Raise the database compatibility level to SQL Server 2016 (compatibility level = 130).
---------------------------------------------------------------------
ALTER DATABASE [TSQL] SET COMPATIBILITY_LEVEL = 130;