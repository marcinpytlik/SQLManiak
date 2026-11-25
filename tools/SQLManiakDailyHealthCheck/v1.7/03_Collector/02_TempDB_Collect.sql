/* SQLManiak DHC v1.6 - TempDB read-only diagnostic add-on
   SQL Server 2022+; VIEW SERVER PERFORMANCE STATE required for DMVs.
   Run in master. NO KILL, NO DDL, NO writes.
   Result set 1: TempDB overview; result set 2: top sessions + oldest active versioning transactions.
   Note: Current-state snapshot only; it cannot reconstruct a completed incident.
*/
SET NOCOUNT ON;
DECLARE @SampleUTC datetime2(3) = SYSUTCDATETIME();

;WITH fs AS
(
    SELECT TotalPages = SUM(CONVERT(bigint,total_page_count)),
           FreePages = SUM(CONVERT(bigint,unallocated_extent_page_count)),
           UserPages = SUM(CONVERT(bigint,user_object_reserved_page_count)),
           InternalPages = SUM(CONVERT(bigint,internal_object_reserved_page_count)),
           VersionPages = SUM(CONVERT(bigint,version_store_reserved_page_count))
    FROM tempdb.sys.dm_db_file_space_usage
),
vol AS
(
    SELECT mf.file_id, mf.name AS FileName, mf.type_desc, mf.size AS SizePages,
           mf.growth, mf.is_percent_growth, mf.max_size,
           vs.volume_mount_point, vs.total_bytes, vs.available_bytes,
           NextGrowthBytes = CONVERT(bigint, CASE WHEN mf.growth = 0 THEN 0
               WHEN mf.is_percent_growth = 1
                    THEN CEILING(CONVERT(decimal(28,4), mf.size)*mf.growth/100.0/8.0)*8*8192
               ELSE CEILING(CONVERT(decimal(28,4), mf.growth)/8.0)*8*8192 END)
    FROM tempdb.sys.database_files AS mf
    CROSS APPLY sys.dm_os_volume_stats(DB_ID('tempdb'),mf.file_id) AS vs
),
vol_summary AS
(
    SELECT MinDriveFreePct = MIN(100.0*available_bytes/NULLIF(total_bytes,0)),
           AnyFileCannotGrow = MAX(CASE WHEN growth=0 OR max_size=0 OR
                     (max_size > 0 AND sizepages >= max_size) OR
                     (max_size > 0 AND nextgrowthbytes > CONVERT(bigint,max_size-sizepages)*8192) OR
                     nextgrowthbytes > available_bytes THEN 1 ELSE 0 END),
           PercentGrowthFileCount = SUM(CASE WHEN is_percent_growth=1 THEN 1 ELSE 0 END),
           DataFileCount = SUM(CASE WHEN type_desc='ROWS' THEN 1 ELSE 0 END),
           LogFileCount = SUM(CASE WHEN type_desc='LOG' THEN 1 ELSE 0 END)
    FROM vol
),
version_tx AS
(
    SELECT ActiveVersioningTransactions = COUNT_BIG(*),
           OldestVersioningSeconds = MAX(CONVERT(bigint,elapsed_time_seconds))
    FROM sys.dm_tran_active_snapshot_database_transactions
    WHERE session_id <> @@SPID
)
SELECT Section='TEMPDB_OVERVIEW', SampleUTC=@SampleUTC,
       TotalDataMB=CONVERT(decimal(19,2),fs.TotalPages/128.0),
       UsedDataMB=CONVERT(decimal(19,2),(fs.TotalPages-fs.FreePages)/128.0),
       FreeDataMB=CONVERT(decimal(19,2),fs.FreePages/128.0),
       DataFreePct=CONVERT(decimal(9,2),100.0*fs.FreePages/NULLIF(fs.TotalPages,0)),
       UserObjectsMB=CONVERT(decimal(19,2),fs.UserPages/128.0),
       InternalObjectsMB=CONVERT(decimal(19,2),fs.InternalPages/128.0),
       VersionStoreMB=CONVERT(decimal(19,2),fs.VersionPages/128.0),
       VersionStoreShareUsedPct=CONVERT(decimal(9,2),100.0*fs.VersionPages/NULLIF(fs.TotalPages-fs.FreePages,0)),
       TotalLogMB=CONVERT(decimal(19,2),ls.total_log_size_in_bytes/1048576.0),
       UsedLogMB=CONVERT(decimal(19,2),ls.used_log_space_in_bytes/1048576.0),
       LogFreePct=CONVERT(decimal(9,2),100.0*(ls.total_log_size_in_bytes-ls.used_log_space_in_bytes)/NULLIF(ls.total_log_size_in_bytes,0)),
       MinDriveFreePct=CONVERT(decimal(9,2),v.MinDriveFreePct),
       AnyFileCannotGrow=v.AnyFileCannotGrow,
       v.PercentGrowthFileCount,v.DataFileCount,v.LogFileCount,
       vt.ActiveVersioningTransactions, vt.OldestVersioningSeconds,
       d.log_reuse_wait_desc AS TempDBLogReuseWait
FROM fs CROSS JOIN tempdb.sys.dm_db_log_space_usage AS ls
CROSS JOIN vol_summary AS v CROSS JOIN version_tx AS vt
CROSS JOIN (SELECT log_reuse_wait_desc FROM sys.databases WHERE database_id=2) AS d;

;WITH alloc AS
(
    SELECT session_id,
           UserPages=CONVERT(bigint,user_objects_alloc_page_count)-CONVERT(bigint,user_objects_dealloc_page_count),
           InternalPages=CONVERT(bigint,internal_objects_alloc_page_count)-CONVERT(bigint,internal_objects_dealloc_page_count)
    FROM tempdb.sys.dm_db_session_space_usage
),
versioning AS
(
    SELECT session_id, MAX(CONVERT(bigint,elapsed_time_seconds)) AS VersioningSeconds
    FROM sys.dm_tran_active_snapshot_database_transactions
    GROUP BY session_id
)
SELECT TOP(20) Section='TEMPDB_SESSIONS', SampleUTC=@SampleUTC,
       s.session_id, COALESCE(r.request_id,-1) AS RequestId, s.login_name,s.host_name,s.program_name,s.status,
       ActiveRequest=CONVERT(bit,CASE WHEN r.session_id IS NULL THEN 0 ELSE 1 END),
       r.command,r.wait_type,r.blocking_session_id,
       SessionUserMB=CONVERT(decimal(19,2),COALESCE(a.UserPages,0)/128.0),
       SessionInternalMB=CONVERT(decimal(19,2),COALESCE(a.InternalPages,0)/128.0),
       SessionAttributedMB=CONVERT(decimal(19,2),(COALESCE(a.UserPages,0)+COALESCE(a.InternalPages,0))/128.0),
       v.VersioningSeconds, s.open_transaction_count,
       r.total_elapsed_time AS RequestElapsedMS
FROM sys.dm_exec_sessions AS s
LEFT JOIN alloc AS a ON a.session_id=s.session_id
LEFT JOIN versioning AS v ON v.session_id=s.session_id
LEFT JOIN sys.dm_exec_requests AS r ON r.session_id=s.session_id
WHERE s.is_user_process=1 AND s.session_id<>@@SPID
  AND (COALESCE(a.UserPages,0)+COALESCE(a.InternalPages,0)>0 OR v.session_id IS NOT NULL)
ORDER BY (COALESCE(a.UserPages,0)+COALESCE(a.InternalPages,0)) DESC,
         COALESCE(v.VersioningSeconds,0) DESC;

/* Result set 3: one row per tempdb file. Check each file and volume individually. */
SELECT Section = 'TEMPDB_FILES', SampleUTC = @SampleUTC,
       f.file_id AS FileId, f.name AS FileName, f.type_desc AS FileType,
       CONVERT(decimal(19,2), f.size / 128.0) AS SizeMB,
       CONVERT(decimal(19,2),CASE WHEN f.max_size = -1 THEN NULL ELSE f.max_size / 128.0 END) AS MaxSizeMB,
       CONVERT(decimal(19,2),CASE WHEN f.is_percent_growth = 0 THEN f.growth / 128.0 ELSE NULL END) AS GrowthMB,
       CONVERT(bit,f.is_percent_growth) AS IsPercentGrowth,
       v.volume_mount_point AS VolumeMountPoint,
       CONVERT(decimal(19,2), v.available_bytes / 1048576.0) AS AvailableVolumeMB,
       CONVERT(decimal(19,2), g.NextGrowthPages / 128.0) AS NextGrowthMB,
       CONVERT(bit,CASE WHEN f.growth=0 OR f.max_size=0
           OR (f.max_size>0 AND f.size>=f.max_size)
           OR (f.max_size>0 AND g.NextGrowthPages>CONVERT(bigint,f.max_size)-f.size)
           OR g.NextGrowthPages*8192>v.available_bytes
           THEN 0 ELSE 1 END) AS NextGrowthWillFit,
       CONVERT(bigint,f.max_size) AS MaxSizePages,
       CONVERT(bigint,f.growth) AS ConfiguredGrowth,
       v.volume_id AS VolumeId
FROM tempdb.sys.database_files AS f
CROSS APPLY sys.dm_os_volume_stats(2, f.file_id) AS v
CROSS APPLY (SELECT NextGrowthPages = CONVERT(bigint,CASE WHEN f.growth=0 THEN 0
    WHEN f.is_percent_growth=1 THEN CEILING(CONVERT(decimal(28,4),f.size)*f.growth/100.0/8.0)*8
    ELSE CEILING(CONVERT(decimal(28,4),f.growth)/8.0)*8 END)) AS g
ORDER BY f.type,f.file_id;
