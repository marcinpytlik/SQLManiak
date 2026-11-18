/*
 E0: read events from event_file.
 For final collection stop session first (03_stop_xe.sql) to flush pending buffers.
 Timestamps in UTC. One row per data field in first result set.
*/
USE master;
GO

;WITH Events AS
(
    SELECT file_name, file_offset,
           TRY_CONVERT(xml, event_data) AS event_xml
    FROM sys.fn_xe_file_target_read_file
    (
        N'/var/opt/mssql/log/bps_research_e0*.xel',
        NULL, NULL, NULL
    )
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

/* Group by extracted SQL columns, not XML methods (SQL error 4148). */
;WITH RawEvents AS
(
    SELECT TRY_CONVERT(xml, event_data) AS event_xml
    FROM sys.fn_xe_file_target_read_file
    (
        N'/var/opt/mssql/log/bps_research_e0*.xel',
        NULL, NULL, NULL
    )
),
ParsedEvents AS
(
    SELECT
        event_xml.value('(/event/@name)[1]', 'sysname') AS EventName,
        event_xml.value('(/event/@timestamp)[1]', 'datetime2(7)') AS EventTimeUTC
    FROM RawEvents
    WHERE event_xml IS NOT NULL
)
SELECT
    EventName,
    COUNT_BIG(*) AS EventCount,
    MIN(EventTimeUTC) AS FirstEventUTC,
    MAX(EventTimeUTC) AS LastEventUTC
FROM ParsedEvents
GROUP BY EventName
ORDER BY EventName;
GO
