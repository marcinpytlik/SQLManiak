-- Module 13 Demo 1

-- Task 1 - Ensure that the Workload1.cmd script is running before 
--          continuing with this demonstration

-- Task 2 - Query the currently executing requests.
--          Note that a large number of requests is returned but that
--          most are system requests.
SELECT * FROM sys.dm_exec_requests;	
GO

-- Task 3 -  The is_user_process column of the sys.dm_exec_sessions view can
--           be used to filter out system activity
SELECT * FROM sys.dm_exec_sessions WHERE is_user_process = 1;
GO

-- Task 4 -  Use that column to filter the currently executing requests
--           by joining the two tables on session_id.
SELECT s.original_login_name, s.program_name, r.command, 
       r.wait_type, r.wait_time, r.blocking_session_id, r.sql_handle
FROM sys.dm_exec_requests AS r
INNER JOIN sys.dm_exec_sessions AS s
ON r.session_id = s.session_id		
WHERE s.is_user_process = 1;
GO

-- Task 5 - Note that we can also retrieve details of the SQL Batch that
--          is being executed, instead of just the handle. We do that by
--          using the sys.dm_exec_sql_text function.
SELECT s.original_login_name, s.program_name, r.command, t.text,
       r.wait_type, r.wait_time, r.blocking_session_id
FROM sys.dm_exec_requests AS r
INNER JOIN sys.dm_exec_sessions AS s
ON r.session_id = s.session_id		
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE s.is_user_process = 1;
GO

-- Task 6 - Do not be too concerned about the complexity of the subquery
--          below but note that it is possible to find the actual statement
--          that is being executed rather than the batch.
SELECT s.original_login_name, s.program_name,  r.command, 
       (SELECT TOP (1) SUBSTRING(t.text, r.statement_start_offset / 2 + 1, 
			                     ((CASE WHEN r.statement_end_offset = -1 
                                   THEN (LEN(CONVERT(nvarchar(max), t.text)) * 2) 
                                   ELSE r.statement_end_offset 
                                   END)  - r.statement_start_offset) / 2 + 1)) AS SqlStatement,
       r.wait_type, r.wait_time, r.blocking_session_id
FROM sys.dm_exec_requests AS r
INNER JOIN sys.dm_exec_sessions AS s
ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text (r.sql_handle) AS t		
WHERE s.is_user_process = 1;
GO

-- Task 7 - Stop the workload 
--          The workload is configured to stop when the ##stopload global
--          temporary table is created.
CREATE TABLE ##stopload (id int);

-- Task 8 - Investigate the query plan cache
SELECT cacheobjtype, 
       objtype , 
       COUNT(*) as CountofPlans, 
       SUM(usecounts) as UsageCount,
       SUM(usecounts)/CAST(count(*)as float) as AvgUsed , 
       SUM(size_in_bytes)/1024./1024. as SizeinMB
FROM sys.dm_exec_cached_plans
GROUP BY cacheobjtype, objtype
ORDER BY CountOfPlans DESC;
GO

-- Task 9 - Locate the top 10 queries based on average logical reads
SELECT TOP (10) total_logical_reads/execution_count AS AvgLogicalReads,
                SUBSTRING(st.text, (qs.statement_start_offset/2) + 1,
                ((CASE statement_end_offset 
                  WHEN -1 THEN DATALENGTH(st.text)
                  ELSE qs.statement_end_offset END 
                 - qs.statement_start_offset)/2) + 1) as StatementText
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY total_logical_reads/execution_count DESC;
GO

-- Task 10 - View I/O statistics for the database files
SELECT DB_NAME(fs.database_id) AS DatabaseName,
       mf.name AS FileName,
       mf.type_desc,
       fs.*
FROM sys.dm_io_virtual_file_stats(NULL,NULL) AS fs
INNER JOIN sys.master_files AS mf
ON fs.database_id = mf.database_id
AND fs.file_id = mf.file_id
ORDER BY fs.database_id, fs.file_id DESC;
GO
	
-- Task 11 - View general wait statistics
SELECT * FROM sys.dm_os_wait_stats;
GO


