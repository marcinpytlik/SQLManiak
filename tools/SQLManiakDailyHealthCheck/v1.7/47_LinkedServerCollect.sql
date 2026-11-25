SET NOCOUNT ON;
-- Read-only metadata; NULL mapping is not proof of absence.
SELECT 'LINKED_SERVER_CONFIGURATION' AS Section, s.server_id AS ServerId,
 s.name AS LinkedServer,s.provider AS Provider,s.data_source AS DataSource,
 s.catalog AS Catalog,s.connect_timeout AS ConnectTimeout,s.query_timeout AS QueryTimeout,
 s.is_data_access_enabled AS DataAccess,s.is_rpc_out_enabled AS RpcOut,
 s.is_collation_compatible AS CollationCompatible,s.uses_remote_collation AS UsesRemoteCollation,
 s.collation_name AS CollationName,s.lazy_schema_validation AS LazySchemaValidation,
 s.is_remote_proc_transaction_promotion_enabled AS TransactionPromotion,s.modify_date AS Modified,
 CONVERT(sysname,SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) AS ActiveNode
FROM sys.servers s WHERE s.is_linked=1 ORDER BY s.name;
SELECT 'LINKED_SERVER_LOGIN_MAPPING' AS Section,s.server_id AS ServerId,s.name AS LinkedServer,
 l.local_principal_id AS LocalPrincipalId,p.name AS LocalLogin,l.uses_self_credential AS SelfCredential,
 l.remote_name AS RemoteLogin,
 CASE WHEN l.server_id IS NULL THEN 'NO VISIBLE MAPPING'
 WHEN l.uses_self_credential=1 THEN 'CURRENT SECURITY CONTEXT'
 WHEN l.remote_name IS NULL THEN 'NO SECURITY CONTEXT'
 ELSE 'EXPLICIT REMOTE LOGIN' END AS MappingType
FROM sys.servers s LEFT JOIN sys.linked_logins l ON s.server_id=l.server_id
LEFT JOIN sys.server_principals p ON p.principal_id=l.local_principal_id
WHERE s.is_linked=1 ORDER BY s.name,l.local_principal_id;
SELECT 'LINKED_SERVER_METADATA_STATUS' AS Section,ORIGINAL_LOGIN() AS CollectorLogin,
 IS_SRVROLEMEMBER('sysadmin') AS IsSysadmin,
 HAS_PERMS_BY_NAME(NULL,NULL,'ALTER ANY LINKED SERVER') AS CanAlterLinkedServer,
 HAS_PERMS_BY_NAME(NULL,NULL,'VIEW ANY DEFINITION') AS CanViewDefinition;
