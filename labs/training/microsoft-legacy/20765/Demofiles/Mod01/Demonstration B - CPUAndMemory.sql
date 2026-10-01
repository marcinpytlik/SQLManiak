-- Demonstration B - CPU and Memory Configurations

-- Step 1: In Object Explorer, right-click the MIA-SQL server and click Properties. In 
--         the Server Properties window, on the General tab, note the values for Platform,
--         Memory and Processors.

-- Step 2: Select the Processors tab, fully expand the tree under the Processor column heading.
--         Note the setting for Max Worker Threads. (0 is the installed default value which 
--         means that the value determined at startup based on the number of CPUs available).
--         Also note the option for Boost SQL Server priority and mention that it is 
--         maintained for backwards compatibility but shouldn't be used in most cases now.

-- Step 3: Select the Advanced tab and in the Parallelism group, review the default values 
-- for Cost Threshold of Parallelism and for Max Degree of Parallelism.

-- Step 4: Select the Memory tab and review the default memory configurations. Click Cancel
--         to close the Server Properties window.
 
-- Step 5: Execute the query below to review the configurations using Transact-SQL
--         Note that the same configurations that you saw in the GUI are available
--         using Transact-SQL.

USE master;
GO

SELECT * FROM sys.configurations;
GO
