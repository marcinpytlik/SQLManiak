/* DHC v1.7 optional read-only capacity module, SQL Server 2016+.
   Execute on a SOURCE instance in master. No permanent objects, DDL or changes
   to databases. Missing rights are recorded as measurement errors.
   GB means GiB (1024 MiB).
*/
SET NOCOUNT ON;
CREATE TABLE #CapFiles(
 DatabaseName sysname NOT NULL, DatabaseId int NOT NULL, FileId int NOT NULL,
 FileType varchar(12) NOT NULL, LogicalFileName sysname NOT NULL, FilegroupName sysname NULL,
 PhysicalName nvarchar(260) NOT NULL, VolumeMountPoint nvarchar(512) NULL,
 AllocatedGB decimal(19,3) NOT NULL, UsedGB decimal(19,3) NULL,
 InternalFreeGB decimal(19,3) NULL, VolumeTotalGB decimal(19,3) NULL,
 VolumeFreeGB decimal(19,3) NULL, MaxSizeGB decimal(19,3) NULL,
 MaxSizeKind varchar(16) NOT NULL, GrowthMB decimal(19,2) NULL,
 IsPercentGrowth bit NOT NULL, IsGrowthEnabled bit NOT NULL
);
CREATE TABLE #CapLogs(
 DatabaseName sysname NOT NULL, DatabaseId int NOT NULL,
 AllocatedLogGB decimal(19,3) NULL, UsedLogGB decimal(19,3) NULL,
 UsedLogPct decimal(9,3) NULL, LogReuseWait nvarchar(60) NULL,
 RecoveryModel nvarchar(60) NULL
);
CREATE TABLE #CapErrors(DatabaseName sysname NOT NULL,Details nvarchar(2000) NOT NULL);
DECLARE @CapDB sysname,@CapId int,@CapSQL nvarchar(max);
DECLARE cap_cursor CURSOR LOCAL FAST_FORWARD FOR
 SELECT name,database_id FROM sys.databases
 WHERE state=0 AND HAS_DBACCESS(name)=1 AND source_database_id IS NULL;
OPEN cap_cursor; FETCH NEXT FROM cap_cursor INTO @CapDB,@CapId;
WHILE @@FETCH_STATUS=0
BEGIN
 BEGIN TRY
  SET @CapSQL=N'USE '+QUOTENAME(@CapDB)+N';
 INSERT #CapFiles(DatabaseName,DatabaseId,FileId,FileType,LogicalFileName,
  FilegroupName,PhysicalName,VolumeMountPoint,AllocatedGB,UsedGB,InternalFreeGB,
  VolumeTotalGB,VolumeFreeGB,MaxSizeGB,MaxSizeKind,GrowthMB,IsPercentGrowth,IsGrowthEnabled)
 SELECT DB_NAME(),DB_ID(),f.file_id,f.type_desc,f.name,fg.name,f.physical_name,
        v.volume_mount_point,
        CAST(f.size/131072.0 AS decimal(19,3)),
        CASE WHEN f.type=0 THEN CAST(FILEPROPERTY(f.name,''SpaceUsed'')/131072.0 AS decimal(19,3)) END,
        CASE WHEN f.type<>0 OR FILEPROPERTY(f.name,''SpaceUsed'') IS NULL THEN NULL ELSE
             CAST((f.size-FILEPROPERTY(f.name,''SpaceUsed''))/131072.0 AS decimal(19,3)) END,
        CAST(v.total_bytes/1073741824.0 AS decimal(19,3)),
        CAST(v.available_bytes/1073741824.0 AS decimal(19,3)),
        CASE WHEN f.max_size>0 THEN CAST(f.max_size/131072.0 AS decimal(19,3)) ELSE NULL END,
        CASE WHEN f.max_size=-1 THEN ''UNLIMITED''
             WHEN f.max_size=0 THEN ''NO_GROWTH'' ELSE ''LIMITED'' END,
        CASE WHEN f.is_percent_growth=1 THEN NULL
             ELSE CAST(f.growth/128.0 AS decimal(19,2)) END,
        f.is_percent_growth,
        CASE WHEN f.growth=0 OR f.max_size=0 THEN 0 ELSE 1 END
 FROM sys.database_files f
 LEFT JOIN sys.filegroups fg ON f.data_space_id=fg.data_space_id
 OUTER APPLY sys.dm_os_volume_stats(DB_ID(),f.file_id) v
 WHERE f.type IN (0,1);';
  EXEC sys.sp_executesql @CapSQL;
 END TRY BEGIN CATCH
  INSERT #CapErrors VALUES(@CapDB,CONCAT('DATA FILES: ',ERROR_MESSAGE()));
 END CATCH;
 BEGIN TRY
  SET @CapSQL=N'USE '+QUOTENAME(@CapDB)+N';
 INSERT #CapLogs(DatabaseName,DatabaseId,AllocatedLogGB,UsedLogGB,UsedLogPct,LogReuseWait,RecoveryModel)
 SELECT DB_NAME(),DB_ID(),
  CAST(l.total_log_size_in_bytes/1073741824.0 AS decimal(19,3)),
  CAST(l.used_log_space_in_bytes/1073741824.0 AS decimal(19,3)),
  CAST(l.used_log_space_in_percent AS decimal(9,3)),
  d.log_reuse_wait_desc,d.recovery_model_desc
 FROM sys.dm_db_log_space_usage l JOIN sys.databases d ON d.database_id=DB_ID();';
  EXEC sys.sp_executesql @CapSQL;
 END TRY BEGIN CATCH
  INSERT #CapErrors VALUES(@CapDB,CONCAT('LOG SPACE: ',ERROR_MESSAGE()));
 END CATCH;
 FETCH NEXT FROM cap_cursor INTO @CapDB,@CapId;
END;
CLOSE cap_cursor; DEALLOCATE cap_cursor;

SELECT N'CAPACITY_FILES' AS Section,DatabaseName,DatabaseId,FileId,
 FileType,LogicalFileName,FilegroupName,PhysicalName,VolumeMountPoint,AllocatedGB,
 UsedGB,InternalFreeGB,VolumeTotalGB,VolumeFreeGB,MaxSizeGB,
 MaxSizeKind,GrowthMB,IsPercentGrowth,IsGrowthEnabled
FROM #CapFiles ORDER BY DatabaseName,FileId;

SELECT N'CAPACITY_LOGS' AS Section,DatabaseName,DatabaseId,
 AllocatedLogGB,UsedLogGB,UsedLogPct,LogReuseWait,RecoveryModel
FROM #CapLogs ORDER BY DatabaseName;

SELECT N'CAPACITY_ERRORS' AS Section,DatabaseName,Details
FROM #CapErrors ORDER BY DatabaseName;
