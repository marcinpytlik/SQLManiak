/* SQLManiak - CDC POC | 04_ReadChanges.sql */
USE CDC_Lab;
GO

DECLARE @from_lsn binary(10), @to_lsn binary(10);
SET @from_lsn = sys.fn_cdc_get_min_lsn(N'dbo_Customer');
SET @to_lsn   = sys.fn_cdc_get_max_lsn();

SELECT
    __$start_lsn,
    sys.fn_cdc_map_lsn_to_time(__$start_lsn) AS CommitTime,
    __$seqval,
    __$operation,
    CASE __$operation
        WHEN 1 THEN 'DELETE'
        WHEN 2 THEN 'INSERT'
        WHEN 3 THEN 'UPDATE_BEFORE'
        WHEN 4 THEN 'UPDATE_AFTER'
    END AS OperationName,
    CustomerId,
    FirstName,
    LastName,
    Email,
    ModifiedDate
FROM cdc.fn_cdc_get_all_changes_dbo_Customer(@from_lsn, @to_lsn, N'all update old')
ORDER BY __$start_lsn, __$seqval, __$operation;
GO

DECLARE @from_lsn binary(10), @to_lsn binary(10);
SET @from_lsn = sys.fn_cdc_get_min_lsn(N'dbo_Customer');
SET @to_lsn   = sys.fn_cdc_get_max_lsn();

SELECT *
FROM cdc.fn_cdc_get_net_changes_dbo_Customer(@from_lsn, @to_lsn, N'all with mask')
ORDER BY CustomerId;
GO

-- Physical CDC change tables for educational inspection.
SELECT * FROM cdc.dbo_Customer_CT ORDER BY __$start_lsn, __$seqval, __$operation;
SELECT * FROM cdc.dbo_CustomerOrder_CT ORDER BY __$start_lsn, __$seqval, __$operation;
GO
