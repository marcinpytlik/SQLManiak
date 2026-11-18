/*
 E0: read events from event_file.
 Run after a controlled operation. For a final collection, stop the XE session
 first using 03_stop_xe.sql to flush pending buffers.
 UTC event timestamps; one row per data field for lossless exploratory analysis.
*/
USE master;
GO
;WITH Events AS
(
    SELECT
        file_name,
        file_offset,
        TRY_CONVERT(xml, event_data) AS event_xml
    FROM sys.fn_xe_file_target_read_file(
         N'/var/opt/mssql/log/bps_research_e0*.xel',
         NULL, NULL, NULL)
)
SELECT
    e.file_name,
    e.file_offset,
    e.event_xml.value('(/event/@name)[1]', 'sysname') AS EventName,
    e.event_xml.value('(/event/@timestamp)[1]', 'datetime2(7)') AS EventTimeUTC,
    d.n.value('@name', 'sysname') AS FieldName,
    d.n.value('(value/text())[1]', 'nvarchar(4000)') AS FieldValue
FROM Events AS e
CROSS APPLY e.event_xml.nodes('/event/data') AS d(n)
ORDER BY EventTimeUTC, e.file_name, e.file_offset, FieldName;
GO

/* Counts by event type. No event != no scanning: some events have thresholds. */
;WITH RawEvents AS
(
    SELECT TRY_CONVERT(xml, event_data) AS event_xml
    FROM sys.fn_xe_file_target_read_file(
         N'/var/opt/mssql/log/bps_research_e0*.xel',
         NULL, NULL, NULL)
)
SELECT
    event_xml.value('(/event/@name)[1]', 'sysname') AS EventName,
    COUNT_BIG(*) AS EventCount,
    MIN(event_xml.value('(/event/@timestamp)[1]', 'datetime2(7)')) AS FirstEventUTC,
    MAX(event_xml.value('(/event/@timestamp)[1]', 'datetime2(7)')) AS LastEventUTC
FROM RawEvents
GROUP BY event_xml.value('(/event/@name)[1]', 'sysname')
ORDER BY EventName;
GO
