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
 $q['CREDENTIAL_METADATA']=@'
SELECT credential_id,name,credential_identity,create_date,modify_date
FROM sys.credentials;
'@
 return $q
}
function Get-ExtendedDatabaseQueries {
 $q=[ordered]@{}
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
 LINKED_SERVER=@('server_id')
 SERVICE=@('servicename')
 VOLUME=@('volume_mount_point')
 HA_CLUSTER=@('cluster_name')
 HA_REPLICA=@('AvailabilityGroupName','replica_server_name')
 HA_DATABASE=@('AvailabilityGroupName','database_name','replica_server_name')
 CREDENTIAL_METADATA=@('credential_id')
 OBJECT=@('DatabaseName','object_id')
 INDEX=@('DatabaseName','object_id','index_id')
 INDEX_PARTITION=@('DatabaseName','object_id','index_id','partition_number')
 STATISTICS=@('DatabaseName','object_id','stats_id')
 PARTITION_FUNCTION=@('DatabaseName','function_id','boundary_id')
 PARTITION_SCHEME=@('DatabaseName','data_space_id','destination_id')
 }
}
