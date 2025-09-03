-- Demonstration A - Version and Edition
-- Five methods for determining the version and edition of a SQL Server instance

-- Method 1: 
-- Explain and demonstrate that in Object Explorer, the server version number is shown in parentheses after the server name (MIA-SQL).

-- Method 2: 
-- In Object Explorer, right-click the server name (MIA-SQL) and click Properties. 
-- On the General page the Product and Version properties are visible.

-- Method 3: 
-- Start Window Explorer. Navigate to C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Log. 
-- Double-click the ERRORLOG file. 
-- On the How do you want to open this file? Dialog, select Notepad. 
-- The first entry in the file displays the version name, version number and edition, amongst other information.

-- Method 4: 
-- Execute the following statement:
-- This returns the version name, version number and edition, amongst other information.
SELECT @@version

-- Method 5: 
-- Execute the following statement:
-- This returns the version, level and edition.
SELECT SERVERPROPERTY('productversion'), SERVERPROPERTY ('productlevel'), SERVERPROPERTY ('edition')

