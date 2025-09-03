-- Module 2 Exercise 1

-- Task 1 - create a server role
-- Write a script to create a server role called database_manager

-- Task 2 - grant permissions
-- Edit the following query to grant permissions to the database_manager role. 
-- The role needs permissions to:
--  - Alter any login
--  - View any database
GRANT  TO database_manager;
GRANT  TO database_manager;

-- Task 3 - assign membership
-- Write a query to make the ADVENTUREWORKS\Database_Managers login a member of the database_managers role. 
-- A login already exists for ADVENTUREWORKS\Database_Managers, so you do not need to create one.

