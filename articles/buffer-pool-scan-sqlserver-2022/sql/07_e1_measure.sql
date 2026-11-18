/*
 E1 MEASURE — execute once for each buffer size after filling.
 Requires XE session BPS_Research_E0 running (start 01_create_xe.sql if stopped).
 Record SSMS results with run label (E1-512, E1-1024, E1-2048).
 This does NOT reset buffer pool globally.
*/
USE master;
GO
SET NOCOUNT ON;
DECLARE @RunLabel varchar(32) = 'E1-512'; -- change with series

SELECT @RunLabel AS RunLabel, SYSUTCDATETIME() AS TimestampUTC,
       COUNT_BIG(*) AS AllDbBufferCount,
       CAST(COUNT_BIG(*)*8.0/1024 AS decimal(18,2)) AS AllDbBufferMiB
FROM sys.dm_os_buffer_descriptors;

-- Read the entire test table to warm its data pages into the buffer pool.
DECLARE @Start datetime2(7) = SYSUTCDATETIME();
DECLARE @Checksum bigint;
SELECT @Checksum = SUM(CONVERT(bigint,DATALENGTH(Payload)))
FROM BPS_E1.dbo.LabPages WITH (INDEX(PK_BPS_E1_LabPages))
OPTION (MAXDOP 1);
SELECT @RunLabel AS RunLabel, @Start AS ReadStartUTC,
       SYSUTCDATETIME() AS ReadEndUTC, @Checksum AS TotalPayloadBytes;

SELECT @RunLabel AS RunLabel, SYSUTCDATETIME() AS TimestampUTC,
       COUNT_BIG(*) AS LabBufferCount,
       CAST(COUNT_BIG(*)*8.0/1024 AS decimal(18,2)) AS LabBufferMiB
FROM sys.dm_os_buffer_descriptors
WHERE database_id = DB_ID(N'BPS_E1');

-- Controlled operation: do not have other sessions connected to BPS_E1.
DECLARE @StartOffline datetime2(7)=SYSUTCDATETIME();
ALTER DATABASE BPS_E1 SET OFFLINE WITH ROLLBACK IMMEDIATE;
DECLARE @AfterOffline datetime2(7)=SYSUTCDATETIME();
ALTER DATABASE BPS_E1 SET ONLINE;
SELECT @RunLabel AS RunLabel, @StartOffline AS OfflineStartUTC,
       @AfterOffline AS OfflineEndUTC, SYSUTCDATETIME() AS OnlineEndUTC;
GO
