/*    ==Scripting Parameters==

    Source Server Version : SQL Server 2017 (14.0.1000)
    Source Database Engine Edition : Microsoft SQL Server Enterprise Edition
    Source Database Engine Type : Standalone SQL Server

    Target Server Version : SQL Server 2017
    Target Database Engine Edition : Microsoft SQL Server Enterprise Edition
    Target Database Engine Type : Standalone SQL Server

	Error in this stored procedure - this needs to be run before completeing Lesson 3 - Demo 2
*/

USE [MDW]
GO

/****** Object:  StoredProcedure [snapshots].[rpt_sql_process_memory]    Script Date: 1/26/2018 7:01:28 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [snapshots].[rpt_sql_process_memory]
    @ServerName sysname,
    @EndTime datetime = NULL,
    @WindowSize int
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Divide our time window up into 40 evenly-sized time intervals, and find the last collection_time within each of these intervals
    CREATE TABLE #intervals (
        interval_time_id        int, 
        interval_start_time     datetimeoffset(7),
        interval_end_time       datetimeoffset(7),
        interval_id             int, 
        first_collection_time   datetimeoffset(7), 
        last_collection_time    datetimeoffset(7), 
        first_snapshot_id       int,
        last_snapshot_id        int, 
        source_id               int, 
        snapshot_id             int, 
        collection_time         datetimeoffset(7), 
        collection_time_id      int
    )
    -- GUID 49268954-... is the Server Activity CS
    INSERT INTO #intervals
    EXEC [snapshots].[rpt_interval_collection_times] 
        @ServerName, @EndTime, @WindowSize, 'snapshots.sql_process_and_system_memory', '49268954-4FD4-4EB6-AA04-CD59D9BB5714', 40, 0

    SELECT 
        CONVERT (datetime, SWITCHOFFSET (CAST (collection_time AS datetimeoffset(7)), '+00:00')) AS collection_time, 
        CASE 
            WHEN series = 'sql_virtual_address_space_reserved_kb' THEN 'Virtual Memory Reserved'
            WHEN series = 'sql_virtual_address_space_committed_kb' THEN 'Virtual Memory Committed'
            WHEN series = 'sql_physical_memory_in_use_kb' THEN 'Physical Memory In Use'
            WHEN series = 'process_physical_memory_low' THEN 'Physical Memory Low'
            WHEN series = 'process_virtual_memory_low' THEN 'Virtual Memory Low'
            ELSE series
        END AS series,
        [value] / 1024 AS [value] -- convert KB to MB
    FROM 
    (
        SELECT 
            pm.collection_time,
            pm.sql_virtual_address_space_reserved_kb,
            pm.sql_virtual_address_space_committed_kb,
            pm.sql_physical_memory_in_use_kb,
            CONVERT (bigint, pm.sql_process_physical_memory_low) AS process_physical_memory_low,
            CONVERT (bigint, pm.sql_process_virtual_memory_low) AS process_virtual_memory_low
        FROM [snapshots].[sql_process_and_system_memory] AS pm
        INNER JOIN #intervals AS i ON (i.last_snapshot_id = pm.snapshot_id AND i.last_collection_time = pm.collection_time)
    ) AS pvt
    UNPIVOT
    (
        [value] for [series] in 
            (sql_virtual_address_space_reserved_kb, sql_virtual_address_space_committed_kb, 
            sql_physical_memory_in_use_kb)
    ) AS unpvt
END
GO


