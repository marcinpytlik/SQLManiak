USE [DBACentralRepository];
GO

IF OBJECT_ID(N'[dbo].[Environment]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Environment]
    (
        EnvironmentId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Environment PRIMARY KEY,
        EnvironmentCode varchar(20) NOT NULL CONSTRAINT UQ_Environment_Code UNIQUE,
        EnvironmentName nvarchar(100) NOT NULL,
        SortOrder int NOT NULL,
        IsProduction bit NOT NULL,
        IsEnabled bit NOT NULL CONSTRAINT DF_Environment_IsEnabled DEFAULT(1)
    );
END;
GO

INSERT [dbo].[Environment](EnvironmentCode,EnvironmentName,SortOrder,IsProduction)
SELECT *
FROM (VALUES
('PROD',N'Produkcja',1,1),
('TEST',N'Test',2,0),
('DEV',N'Development',3,0),
('DR',N'Disaster Recovery',4,0),
('OTHER',N'Inne',99,0)
) V(EnvironmentCode,EnvironmentName,SortOrder,IsProduction)
WHERE NOT EXISTS
(
    SELECT 1 FROM [dbo].[Environment] E
    WHERE E.EnvironmentCode=V.EnvironmentCode
);
GO

IF OBJECT_ID(N'[dbo].[ScanRun]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[ScanRun]
    (
        ScanRunId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ScanRun PRIMARY KEY,
        ScanType varchar(30) NOT NULL,
        ScanStartedAt datetime2(0) NOT NULL CONSTRAINT DF_ScanRun_Started DEFAULT(SYSDATETIME()),
        ScanFinishedAt datetime2(0) NULL,
        CollectorHost nvarchar(256) NULL,
        CollectorUser nvarchar(256) NULL,
        RepositoryServer nvarchar(256) NULL,
        Status varchar(30) NOT NULL CONSTRAINT DF_ScanRun_Status DEFAULT('RUNNING'),
        InstanceCount int NOT NULL CONSTRAINT DF_ScanRun_InstanceCount DEFAULT(0),
        ObjectCount int NOT NULL CONSTRAINT DF_ScanRun_ObjectCount DEFAULT(0),
        ErrorCount int NOT NULL CONSTRAINT DF_ScanRun_ErrorCount DEFAULT(0)
    );
END;
GO

IF OBJECT_ID(N'[dbo].[Instance]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Instance]
    (
        InstanceId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Instance PRIMARY KEY,
        ServerInstance nvarchar(256) NOT NULL CONSTRAINT UQ_Instance_ServerInstance UNIQUE,
        EnvironmentId int NULL,
        Description nvarchar(500) NULL,
        MachineName nvarchar(256) NULL,
        ServerName nvarchar(256) NULL,
        InstanceName nvarchar(256) NULL,
        ProductVersion nvarchar(128) NULL,
        ProductLevel nvarchar(128) NULL,
        Edition nvarchar(256) NULL,
        EngineEdition int NULL,
        ProductMajorVersion int NULL,
        IsClustered bit NULL,
        IsHadrEnabled bit NULL,
        IsEnabled bit NOT NULL CONSTRAINT DF_Instance_IsEnabled DEFAULT(1),
        IsReachable bit NOT NULL CONSTRAINT DF_Instance_IsReachable DEFAULT(0),
        LastSeenAt datetime2(0) NULL,
        LastScanRunId bigint NULL,
        LastError nvarchar(max) NULL,
        CONSTRAINT FK_Instance_Environment FOREIGN KEY(EnvironmentId) REFERENCES [dbo].[Environment](EnvironmentId),
        CONSTRAINT FK_Instance_LastScanRun FOREIGN KEY(LastScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId)
    );
END;
GO

IF OBJECT_ID(N'[dbo].[ScanError]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[ScanError]
    (
        ScanErrorId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ScanError PRIMARY KEY,
        ScanRunId bigint NOT NULL,
        InstanceId bigint NULL,
        ModuleName varchar(30) NOT NULL,
        ObjectName nvarchar(512) NULL,
        StageName nvarchar(128) NULL,
        ErrorNumber int NULL,
        ErrorMessage nvarchar(max) NOT NULL,
        ErrorAt datetime2(0) NOT NULL CONSTRAINT DF_ScanError_ErrorAt DEFAULT(SYSDATETIME()),
        CONSTRAINT FK_ScanError_ScanRun FOREIGN KEY(ScanRunId) REFERENCES [dbo].[ScanRun](ScanRunId),
        CONSTRAINT FK_ScanError_Instance FOREIGN KEY(InstanceId) REFERENCES [dbo].[Instance](InstanceId)
    );
END;
GO

IF OBJECT_ID(N'[dbo].[RetentionPolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[RetentionPolicy]
    (
        RetentionPolicyId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_RetentionPolicy PRIMARY KEY,
        SchemaName sysname NOT NULL,
        TableName sysname NOT NULL,
        DateColumnName sysname NOT NULL,
        RetentionDays int NOT NULL,
        IsEnabled bit NOT NULL CONSTRAINT DF_RetentionPolicy_IsEnabled DEFAULT(1),
        CONSTRAINT UQ_RetentionPolicy UNIQUE(SchemaName,TableName)
    );
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_SetDescription]
    @SchemaName sysname,
    @ObjectName sysname = NULL,
    @ObjectType varchar(20) = 'SCHEMA',
    @Description nvarchar(4000)
AS
BEGIN
    SET NOCOUNT ON;

    IF @ObjectType='SCHEMA'
    BEGIN
        IF EXISTS
        (
            SELECT 1 FROM [sys].[extended_properties]
            WHERE class=3 AND major_id=SCHEMA_ID(@SchemaName) AND name=N'MS_Description'
        )
            EXEC [sys].[sp_updateextendedproperty]
                @name=N'MS_Description',@value=@Description,
                @level0type=N'SCHEMA',@level0name=@SchemaName;
        ELSE
            EXEC [sys].[sp_addextendedproperty]
                @name=N'MS_Description',@value=@Description,
                @level0type=N'SCHEMA',@level0name=@SchemaName;
        RETURN;
    END;

    DECLARE @Level1Type nvarchar(20)=
        CASE @ObjectType WHEN 'VIEW' THEN N'VIEW'
                         WHEN 'PROCEDURE' THEN N'PROCEDURE'
                         ELSE N'TABLE' END;

    IF EXISTS
    (
        SELECT 1
        FROM [sys].[extended_properties] EP
        JOIN [sys].[objects] O ON O.object_id=EP.major_id
        WHERE EP.class=1
          AND EP.name=N'MS_Description'
          AND O.schema_id=SCHEMA_ID(@SchemaName)
          AND O.name=@ObjectName
    )
        EXEC [sys].[sp_updateextendedproperty]
            @name=N'MS_Description',@value=@Description,
            @level0type=N'SCHEMA',@level0name=@SchemaName,
            @level1type=@Level1Type,@level1name=@ObjectName;
    ELSE
        EXEC [sys].[sp_addextendedproperty]
            @name=N'MS_Description',@value=@Description,
            @level0type=N'SCHEMA',@level0name=@SchemaName,
            @level1type=@Level1Type,@level1name=@ObjectName;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_StartScan]
    @ScanType varchar(30),
    @CollectorHost nvarchar(256),
    @CollectorUser nvarchar(256),
    @RepositoryServer nvarchar(256),
    @ScanRunId bigint OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT [dbo].[ScanRun](ScanType,CollectorHost,CollectorUser,RepositoryServer)
    VALUES(@ScanType,@CollectorHost,@CollectorUser,@RepositoryServer);
    SET @ScanRunId=SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_FinishScan]
    @ScanRunId bigint,
    @Status varchar(30),
    @InstanceCount int,
    @ObjectCount int,
    @ErrorCount int
AS
BEGIN
    UPDATE [dbo].[ScanRun]
    SET ScanFinishedAt=SYSDATETIME(),
        Status=@Status,
        InstanceCount=@InstanceCount,
        ObjectCount=@ObjectCount,
        ErrorCount=@ErrorCount
    WHERE ScanRunId=@ScanRunId;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_LogScanError]
    @ScanRunId bigint,
    @InstanceId bigint=NULL,
    @ModuleName varchar(30),
    @ObjectName nvarchar(512)=NULL,
    @StageName nvarchar(128)=NULL,
    @ErrorNumber int=NULL,
    @ErrorMessage nvarchar(max)
AS
BEGIN
    INSERT [dbo].[ScanError]
    (
        ScanRunId,InstanceId,ModuleName,ObjectName,StageName,ErrorNumber,ErrorMessage
    )
    VALUES
    (
        @ScanRunId,@InstanceId,@ModuleName,@ObjectName,@StageName,@ErrorNumber,@ErrorMessage
    );
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_UpsertInstance]
    @ServerInstance nvarchar(256),
    @EnvironmentCode varchar(20),
    @Description nvarchar(500)=NULL,
    @MachineName nvarchar(256)=NULL,
    @ServerName nvarchar(256)=NULL,
    @InstanceName nvarchar(256)=NULL,
    @ProductVersion nvarchar(128)=NULL,
    @ProductLevel nvarchar(128)=NULL,
    @Edition nvarchar(256)=NULL,
    @EngineEdition int=NULL,
    @ProductMajorVersion int=NULL,
    @IsClustered bit=NULL,
    @IsHadrEnabled bit=NULL,
    @ScanRunId bigint,
    @IsReachable bit,
    @LastError nvarchar(max)=NULL,
    @InstanceId bigint OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EnvironmentId int=
    (
        SELECT EnvironmentId FROM [dbo].[Environment]
        WHERE EnvironmentCode=@EnvironmentCode
    );

    IF @EnvironmentId IS NULL
        SELECT @EnvironmentId=EnvironmentId
        FROM [dbo].[Environment] WHERE EnvironmentCode='OTHER';

    MERGE [dbo].[Instance] AS T
    USING (SELECT @ServerInstance ServerInstance) AS S
       ON T.ServerInstance=S.ServerInstance
    WHEN MATCHED THEN UPDATE SET
        EnvironmentId=@EnvironmentId,
        Description=@Description,
        MachineName=@MachineName,
        ServerName=@ServerName,
        InstanceName=@InstanceName,
        ProductVersion=@ProductVersion,
        ProductLevel=@ProductLevel,
        Edition=@Edition,
        EngineEdition=@EngineEdition,
        ProductMajorVersion=@ProductMajorVersion,
        IsClustered=@IsClustered,
        IsHadrEnabled=@IsHadrEnabled,
        IsReachable=@IsReachable,
        LastSeenAt=SYSDATETIME(),
        LastScanRunId=@ScanRunId,
        LastError=@LastError
    WHEN NOT MATCHED THEN INSERT
    (
        ServerInstance,EnvironmentId,Description,MachineName,ServerName,InstanceName,
        ProductVersion,ProductLevel,Edition,EngineEdition,ProductMajorVersion,
        IsClustered,IsHadrEnabled,IsReachable,LastSeenAt,LastScanRunId,LastError
    )
    VALUES
    (
        @ServerInstance,@EnvironmentId,@Description,@MachineName,@ServerName,@InstanceName,
        @ProductVersion,@ProductLevel,@Edition,@EngineEdition,@ProductMajorVersion,
        @IsClustered,@IsHadrEnabled,@IsReachable,SYSDATETIME(),@ScanRunId,@LastError
    );

    SELECT @InstanceId=InstanceId
    FROM [dbo].[Instance]
    WHERE ServerInstance=@ServerInstance;
END;
GO
