/*
  SQLManiak Index Maintenance - extensible infrastructure topology (v1).
  Apply after 001-005. Non-destructive migration; no discovery or REBUILD.
*/
USE [SQLManiakIndexMaintenance];
GO
IF OBJECT_ID(N'im.Cluster',N'U') IS NULL
BEGIN
 CREATE TABLE im.Cluster(
  ClusterId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_im_Cluster PRIMARY KEY,
  ClusterName nvarchar(256) NOT NULL CONSTRAINT UQ_im_Cluster_Name UNIQUE,
  IsEnabled bit NOT NULL CONSTRAINT DF_im_Cluster_Enabled DEFAULT(1),
  MaxConcurrentHeavyAudits int NOT NULL CONSTRAINT DF_im_Cluster_Concurrent DEFAULT(1),
  CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_im_Cluster_Created DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT CK_im_Cluster_Concurrency CHECK (MaxConcurrentHeavyAudits BETWEEN 1 AND 64)
 );
END;
GO
IF OBJECT_ID(N'im.ClusterNode',N'U') IS NULL
BEGIN
 CREATE TABLE im.ClusterNode(
  ClusterNodeId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_im_ClusterNode PRIMARY KEY,
  ClusterId bigint NOT NULL CONSTRAINT FK_im_ClusterNode_Cluster REFERENCES im.Cluster(ClusterId),
  NodeName nvarchar(256) NOT NULL,
  IsEnabled bit NOT NULL CONSTRAINT DF_im_ClusterNode_Enabled DEFAULT(1),
  CONSTRAINT UQ_im_ClusterNode_Name UNIQUE(ClusterId,NodeName)
 );
END;
GO
IF COL_LENGTH(N'im.ManagedInstance',N'ClusterId') IS NULL
 ALTER TABLE im.ManagedInstance ADD ClusterId bigint NULL;
GO
IF COL_LENGTH(N'im.ManagedInstance',N'InstanceType') IS NULL
 ALTER TABLE im.ManagedInstance ADD InstanceType varchar(16) NOT NULL
 CONSTRAINT DF_im_ManagedInstance_Type DEFAULT('UNKNOWN');
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_im_ManagedInstance_Cluster')
 ALTER TABLE im.ManagedInstance WITH CHECK ADD CONSTRAINT FK_im_ManagedInstance_Cluster
 FOREIGN KEY(ClusterId) REFERENCES im.Cluster(ClusterId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CK_im_ManagedInstance_Type')
 ALTER TABLE im.ManagedInstance WITH CHECK ADD CONSTRAINT CK_im_ManagedInstance_Type
 CHECK(InstanceType IN ('UNKNOWN','FCI','STANDALONE','AG_REPLICA'));
GO
IF OBJECT_ID(N'im.ConnectionEndpoint',N'U') IS NULL
BEGIN
 CREATE TABLE im.ConnectionEndpoint(
  EndpointId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_im_ConnectionEndpoint PRIMARY KEY,
  InstanceId bigint NOT NULL CONSTRAINT FK_im_ConnectionEndpoint_Instance REFERENCES im.ManagedInstance(InstanceId),
  ServerAddress nvarchar(256) NOT NULL,
  Port int NULL,
  IsPrimary bit NOT NULL CONSTRAINT DF_im_ConnectionEndpoint_Primary DEFAULT(1),
  IsEnabled bit NOT NULL CONSTRAINT DF_im_ConnectionEndpoint_Enabled DEFAULT(0),
  CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_im_ConnectionEndpoint_Created DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT CK_im_ConnectionEndpoint_Port CHECK(Port IS NULL OR Port BETWEEN 1 AND 65535),
  CONSTRAINT UQ_im_ConnectionEndpoint UNIQUE(InstanceId,ServerAddress,Port)
 );
 CREATE UNIQUE INDEX UX_im_ConnectionEndpoint_Primary
 ON im.ConnectionEndpoint(InstanceId) WHERE IsPrimary=1;
END;
GO
IF OBJECT_ID(N'im.AuditPolicy',N'U') IS NULL
BEGIN
 CREATE TABLE im.AuditPolicy(
  PolicyId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_im_AuditPolicy PRIMARY KEY,
  PolicyName sysname NOT NULL CONSTRAINT UQ_im_AuditPolicy_Name UNIQUE,
  MinPagesForReview int NOT NULL CONSTRAINT DF_im_AuditPolicy_Review DEFAULT(1000),
  MinPagesForSample int NOT NULL CONSTRAINT DF_im_AuditPolicy_Sample DEFAULT(10000),
  MaxSampledPartitions int NOT NULL CONSTRAINT DF_im_AuditPolicy_MaxSample DEFAULT(20),
  IsEnabled bit NOT NULL CONSTRAINT DF_im_AuditPolicy_Enabled DEFAULT(1),
  CONSTRAINT CK_im_AuditPolicy_Params CHECK(
   MinPagesForReview >= 1 AND MinPagesForSample >= MinPagesForReview
   AND MaxSampledPartitions BETWEEN 0 AND 1000)
 );
END;
GO
IF COL_LENGTH(N'im.ManagedDatabase',N'PolicyId') IS NULL
 ALTER TABLE im.ManagedDatabase ADD PolicyId bigint NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_im_ManagedDatabase_Policy')
 ALTER TABLE im.ManagedDatabase WITH CHECK ADD CONSTRAINT FK_im_ManagedDatabase_Policy
 FOREIGN KEY(PolicyId) REFERENCES im.AuditPolicy(PolicyId);
GO
IF NOT EXISTS (SELECT 1 FROM im.AuditPolicy WHERE PolicyName=N'Default')
 INSERT im.AuditPolicy(PolicyName) VALUES(N'Default');
GO
