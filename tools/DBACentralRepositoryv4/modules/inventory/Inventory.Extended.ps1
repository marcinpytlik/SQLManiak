#requires -Version 7.0
<#
 Extended SQL Server metadata queries, designed for SQL Server 2016+.
 This file is dot-sourced by Collect-DBAInventory.ps1.
 No table scans or UPDATE STATISTICS are performed.
#>
function Get-ExtendedServerQueries {
 $q=[ordered]@{}
 $q['TEMPDB']=@'
SELECT DB_NAME(database_id) AS DatabaseName,file_id,name,type_desc,physical_name,
size,growth,is_percent_growth,max_size
FROM sys.master_files WHERE database_id=2;
'@
 $q['LINKED_SERVER']=@'
SELECT server_id,name,product,provider,data_source,location,catalog,
is_linked,is_remote_login_enabled,is_rpc_out_enabled,
is_data_access_enabled,is_collation_compatible
FROM sys.servers WHERE server_id<>0;
'@
 $q['SERVICE']=@'
SELECT servicename,startup_type_desc,status_desc,last_startup_time,
service_account,filename
FROM sys.dm_server_services;
'@
 $q['VOLUME']=@'
SELECT DISTINCT vs.volume_mount_point,vs.logical_volume_name,
vs.total_bytes,vs.available_bytes,vs.file_system_type,
vs.supports_compression
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id,mf.file_id) vs;
'@
 $q['HA_CLUSTER']=@'
SELECT CAST(SERVERPROPERTY('MachineName') AS nvarchar(128)) AS ClusterName,
NodeName,status_description AS NodeStatus,is_current_owner AS IsCurrentOwner
FROM sys.dm_os_cluster_nodes;
'@
 $q['HA_REPLICA']=@'
SELECT ag.name AS AvailabilityGroupName,ar.replica_server_name,
ar.availability_mode_desc,ar.failover_mode_desc,
ar.secondary_role_allow_connections_desc,ars.role_desc,
ars.connected_state_desc,ars.synchronization_health_desc
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ar.group_id=ag.group_id
LEFT JOIN sys.dm_hadr_availability_replica_states ars
 ON ars.replica_id=ar.replica_id AND ars.is_local=1;
'@
 $q['HA_DATABASE']=@'
SELECT ag.name AvailabilityGroupName,adc.database_name,
ar.replica_server_name,drs.is_local,drs.is_suspended,
drs.synchronization_state_desc,drs.synchronization_health_desc
FROM sys.availability_databases_cluster adc
JOIN sys.availability_groups ag ON ag.group_id=adc.group_id
JOIN sys.availability_replicas ar ON ar.group_id=ag.group_id
LEFT JOIN sys.dm_hadr_database_replica_states drs
 ON drs.group_id=adc.group_id AND drs.replica_id=ar.replica_id
 AND drs.group_database_id=adc.group_database_id;
'@
 $q['TRACE_FLAG']=@'
DBCC TRACESTATUS(-1) WITH NO_INFOMSGS;
'@
 $q['CREDENTIAL_METADATA']=@'
SELECT credential_id,name,credential_identity,create_date,modify_date
FROM sys.credentials;
'@
 return $q
}
function Get-ExtendedDatabaseQueries {
 $q=[ordered]@{}
 $q['SCHEMA']=@'
SELECT DB_NAME() DatabaseName,s.schema_id,s.name SchemaName,USER_NAME(s.principal_id) OwnerName
FROM sys.schemas s WHERE s.schema_id<>0;
'@
 $q['COLUMN']=@'
SELECT DB_NAME() DatabaseName,sch.name SchemaName,o.name ObjectName,
c.object_id,c.column_id,c.name ColumnName,ty.name TypeName,
c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity,c.is_computed,
c.collation_name
FROM sys.columns c
JOIN sys.objects o ON o.object_id=c.object_id AND o.is_ms_shipped=0
JOIN sys.schemas sch ON sch.schema_id=o.schema_id
JOIN sys.types ty ON ty.user_type_id=c.user_type_id
WHERE o.type IN ('U','V','TF','IF');
'@
 $q['OBJECT']=@'
SELECT DB_NAME() DatabaseName,s.name SchemaName,o.name ObjectName,
o.object_id,o.type,o.type_desc,o.create_date,o.modify_date,
CASE WHEN o.type='U' THEN CAST(t.is_memory_optimized AS int) ELSE NULL END IsMemoryOptimized,
CASE WHEN o.type='U' THEN CAST(t.temporal_type_desc AS nvarchar(60)) ELSE NULL END TemporalType
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id=s.schema_id
LEFT JOIN sys.tables t ON t.object_id=o.object_id
WHERE o.is_ms_shipped=0 AND o.type IN ('U','V','P','PC','FN','IF','TF','FS','FT','TR','SN','SO');
'@
 $q['INDEX']=@'
SELECT DB_NAME() DatabaseName,sch.name SchemaName,obj.name ObjectName,
obj.object_id,i.index_id,i.name IndexName,i.type_desc,i.is_unique,i.is_primary_key,
i.is_unique_constraint,i.fill_factor,i.is_disabled,i.is_hypothetical,
i.has_filter,i.filter_definition,i.allow_row_locks,i.allow_page_locks
FROM sys.indexes i
JOIN sys.objects obj ON obj.object_id=i.object_id AND obj.is_ms_shipped=0
JOIN sys.schemas sch ON sch.schema_id=obj.schema_id
WHERE obj.type IN ('U','V');
'@
 $q['INDEX_COLUMN']=@'
SELECT DB_NAME() DatabaseName,ic.object_id,ic.index_id,ic.index_column_id,
ic.key_ordinal,ic.is_descending_key,ic.is_included_column,
ic.partition_ordinal,c.name ColumnName
FROM sys.index_columns ic
JOIN sys.objects o ON o.object_id=ic.object_id AND o.is_ms_shipped=0
JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id;
'@
 $q['INDEX_PARTITION']=@'
SELECT DB_NAME() DatabaseName,sch.name SchemaName,t.name TableName,
p.object_id,p.index_id,p.partition_number,p.rows AS ApproxRowCount,
p.data_compression_desc,p.partition_id
FROM sys.partitions p
JOIN sys.tables t ON t.object_id=p.object_id AND t.is_ms_shipped=0
JOIN sys.schemas sch ON sch.schema_id=t.schema_id;
'@
 $q['STATISTICS']=@'
SELECT DB_NAME() DatabaseName,sch.name SchemaName,o.name ObjectName,
st.object_id,st.stats_id,st.name StatisticName,st.auto_created,
st.user_created,st.no_recompute,st.has_filter,st.filter_definition,
STATS_DATE(st.object_id,st.stats_id) LastUpdatedUtcOrLocal
FROM sys.stats st
JOIN sys.objects o ON o.object_id=st.object_id AND o.is_ms_shipped=0
JOIN sys.schemas sch ON sch.schema_id=o.schema_id;
'@
 $q['STATISTICS_COLUMN']=@'
SELECT DB_NAME() DatabaseName,sc.object_id,sc.stats_id,sc.stats_column_id,
c.name ColumnName
FROM sys.stats_columns sc
JOIN sys.objects o ON o.object_id=sc.object_id AND o.is_ms_shipped=0
JOIN sys.columns c ON c.object_id=sc.object_id AND c.column_id=sc.column_id;
'@
 $q['FOREIGN_KEY']=@'
SELECT DB_NAME() DatabaseName,fk.object_id,fk.name ForeignKeyName,
OBJECT_SCHEMA_NAME(fk.parent_object_id) ParentSchema,
OBJECT_NAME(fk.parent_object_id) ParentTable,
OBJECT_SCHEMA_NAME(fk.referenced_object_id) ReferencedSchema,
OBJECT_NAME(fk.referenced_object_id) ReferencedTable,
fk.is_disabled,fk.is_not_trusted,fk.delete_referential_action_desc,
fk.update_referential_action_desc
FROM sys.foreign_keys fk JOIN sys.tables t ON t.object_id=fk.parent_object_id
WHERE t.is_ms_shipped=0;
'@
 $q['PARTITION_FUNCTION']=@'
SELECT DB_NAME() DatabaseName,pf.function_id,pf.name FunctionName,
pf.boundary_value_on_right,pf.fanout,pf.create_date,pf.modify_date,
prv.boundary_id,CONVERT(nvarchar(4000),prv.value) BoundaryValue
FROM sys.partition_functions pf
LEFT JOIN sys.partition_range_values prv ON prv.function_id=pf.function_id;
'@
 $q['PARTITION_SCHEME']=@'
SELECT DB_NAME() DatabaseName,ps.data_space_id,ps.name SchemeName,
pf.name FunctionName,dds.destination_id,fg.name FilegroupName
FROM sys.partition_schemes ps
JOIN sys.partition_functions pf ON pf.function_id=ps.function_id
LEFT JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id=ps.data_space_id
LEFT JOIN sys.filegroups fg ON fg.data_space_id=dds.data_space_id;
'@
 return $q
}
function Get-ExtendedKeys {
 return @{
 TEMPDB=@('DatabaseName','file_id')
 TRACE_FLAG=@('TraceFlag','Global','Session')
 LINKED_SERVER=@('server_id')
 SERVICE=@('servicename')
 VOLUME=@('volume_mount_point')
 HA_CLUSTER=@('cluster_name')
 HA_REPLICA=@('AvailabilityGroupName','replica_server_name')
 HA_DATABASE=@('AvailabilityGroupName','database_name','replica_server_name')
 CREDENTIAL_METADATA=@('credential_id')
 OBJECT=@('DatabaseName','object_id')
 SCHEMA=@('DatabaseName','schema_id')
 COLUMN=@('DatabaseName','object_id','column_id')
 FOREIGN_KEY=@('DatabaseName','object_id')
 INDEX=@('DatabaseName','object_id','index_id')
 INDEX_COLUMN=@('DatabaseName','object_id','index_id','index_column_id')
 INDEX_PARTITION=@('DatabaseName','object_id','index_id','partition_number')
 STATISTICS=@('DatabaseName','object_id','stats_id')
 STATISTICS_COLUMN=@('DatabaseName','object_id','stats_id','stats_column_id')
 PARTITION_FUNCTION=@('DatabaseName','function_id','boundary_id')
 PARTITION_SCHEME=@('DatabaseName','data_space_id','destination_id')
 }
}
