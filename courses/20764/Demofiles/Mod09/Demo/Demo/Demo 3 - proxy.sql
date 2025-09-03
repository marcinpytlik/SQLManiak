-- Module 9 - Demo 3

-- Task 1
USE msdb
GO
EXEC dbo.sp_add_proxy 
		@proxy_name=N'FileOp',
		@credential_name=N'FileOperation', 
		@enabled=1;
GO

-- Task 2
SELECT * 
FROM dbo.sysproxies AS sp
JOIN sys.credentials AS c
ON sp.credential_id = c.credential_id;
GO

-- Task 3
SELECT * from msdb.dbo.syssubsystems;
GO

-- Task 4
EXEC dbo.sp_grant_proxy_to_subsystem 
		@proxy_name=N'FileOp', 
		@subsystem_id=3
GO

