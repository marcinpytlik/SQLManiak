-- View page usage
USE InternetSales;
SELECT f.name FileName, fg.name Filegroup, u.allocated_extent_page_count UsedPages, u.total_page_count TotalPages
FROM sys.sysfiles f
JOIN sys.filegroups fg ON f.groupid = fg.data_space_id
JOIN sys.dm_db_file_space_usage u ON u.file_id = f.fileid;
GO

-- Create a table on the SalesData filegroup
CREATE TABLE SalesOrder
(OrderID int IDENTITY PRIMARY KEY,
 OrderDate datetime DEFAULT GETDATE())
ON SalesData;
GO

-- Insert 10,000 rows
INSERT INTO SalesOrder
VALUES (DEFAULT);
GO 10000

-- View page usage again
SELECT f.name FileName, fg.name Filegroup, u.allocated_extent_page_count UsedPages, u.total_page_count TotalPages
FROM sys.sysfiles f
JOIN sys.filegroups fg ON f.groupid = fg.data_space_id
JOIN sys.dm_db_file_space_usage u ON u.file_id = f.fileid;
GO
