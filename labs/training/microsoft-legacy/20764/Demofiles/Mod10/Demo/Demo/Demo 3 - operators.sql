--Module 10 Demo 3

-- Task 1 - enable SQL Agent mail

-- Task 2 - create an operator
USE msdb
GO
EXEC msdb.dbo.sp_add_operator @name=N'Student', 
		@enabled=1, 
		@pager_days=0, 
		@email_address=N'student@adventureworks.msft'
GO

-- Task 3 - configure a job to notify an operator
