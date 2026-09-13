/* TEST 06 - Schema evolution with second capture instance */
USE CDC_Lab;
GO

ALTER TABLE dbo.Customer
ADD PhoneNumber varchar(30) NULL;
GO

EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @capture_instance = N'dbo_Customer_v2',
    @role_name = NULL,
    @supports_net_changes = 1,
    @filegroup_name = N'CDC_CT';
GO

EXEC sys.sp_cdc_help_change_data_capture
    @source_schema = N'dbo',
    @source_name = N'Customer';
GO

EXEC sys.sp_cdc_get_captured_columns
    @capture_instance = N'dbo_Customer';
GO

EXEC sys.sp_cdc_get_captured_columns
    @capture_instance = N'dbo_Customer_v2';
GO

INSERT dbo.Customer (FirstName, LastName, Email, PhoneNumber)
VALUES ('Schema','Evolution','schema@test.local','+48-500-600-700');
GO

WAITFOR DELAY '00:00:05';
GO

SELECT TOP (20) *
FROM cdc.dbo_Customer_CT
ORDER BY __$start_lsn DESC;
GO

SELECT TOP (20) *
FROM cdc.dbo_Customer_v2_CT
ORDER BY __$start_lsn DESC;
GO

/*
PASS:
- old capture instance still works with its original column set,
- dbo_Customer_v2 contains PhoneNumber,
- both capture instances receive the new business change,
- filegroup_name for v2 is CDC_CT.

Cleanup after the test, only when no longer needed:
EXEC sys.sp_cdc_disable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @capture_instance = N'dbo_Customer_v2';
*/
