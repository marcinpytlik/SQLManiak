USE [DBACentralRepository];
GO

/*
===============================================================================
Plik: 15_Create_SSRS_Job_Mapping.sql
Projekt: DBACentralRepository v3

Cel:
    Mapowanie jobów SQL Server Agent o nazwach GUID, tworzonych przez
    SQL Server Reporting Services, na raporty, subskrypcje i harmonogramy SSRS.

Ważne:
    - Nie zmieniamy nazw jobów w msdb.
    - FriendlyJobName istnieje wyłącznie w centralnym repozytorium.
    - Jeden job SSRS może mapować się na wiele subskrypcji lub raportów.
===============================================================================
*/

IF OBJECT_ID(N'[job].[SsrsJobMapping]', N'U') IS NULL
BEGIN
    CREATE TABLE [job].[SsrsJobMapping]
    (
        [SsrsJobMappingId] bigint IDENTITY(1,1) NOT NULL,
        [ScanRunId] bigint NOT NULL,
        [InstanceId] bigint NOT NULL,

        [ReportServerDatabase] sysname NOT NULL,

        [SqlAgentJobId] uniqueidentifier NOT NULL,
        [SqlAgentJobName] sysname NOT NULL,

        [ScheduleId] uniqueidentifier NULL,
        [SubscriptionId] uniqueidentifier NULL,
        [ReportId] uniqueidentifier NULL,

        [ReportName] nvarchar(425) NULL,
        [ReportPath] nvarchar(2000) NULL,

        [SubscriptionDescription] nvarchar(1024) NULL,
        [SubscriptionOwner] nvarchar(256) NULL,
        [DeliveryExtension] nvarchar(260) NULL,

        [LastStatus] nvarchar(2000) NULL,
        [LastRunTime] datetime NULL,

        [ScheduleName] nvarchar(425) NULL,
        [ScheduleNextRunTime] datetime NULL,
        [ScheduleLastRunTime] datetime NULL,

        [SsrsJobType] varchar(50) NOT NULL,
        [FriendlyJobName] nvarchar(2000) NOT NULL,

        [CapturedAt] datetime2(0) NOT NULL,

        CONSTRAINT [PK_SsrsJobMapping]
            PRIMARY KEY CLUSTERED ([SsrsJobMappingId]),

        CONSTRAINT [FK_SsrsJobMapping_ScanRun]
            FOREIGN KEY ([ScanRunId])
            REFERENCES [dbo].[ScanRun] ([ScanRunId]),

        CONSTRAINT [FK_SsrsJobMapping_Instance]
            FOREIGN KEY ([InstanceId])
            REFERENCES [dbo].[Instance] ([InstanceId])
    );

    CREATE INDEX [IX_SsrsJobMapping_Instance_Job_Scan]
        ON [job].[SsrsJobMapping]
        (
            [InstanceId],
            [SqlAgentJobId],
            [ScanRunId]
        )
        INCLUDE
        (
            [FriendlyJobName],
            [ReportPath],
            [SubscriptionDescription],
            [CapturedAt]
        );

    CREATE INDEX [IX_SsrsJobMapping_ScanRun]
        ON [job].[SsrsJobMapping]
        (
            [ScanRunId],
            [InstanceId]
        );
END;
GO

CREATE OR ALTER VIEW [report].[vCurrentSsrsJobMapping]
AS
WITH LatestScan AS
(
    SELECT
        M.[InstanceId],
        MAX(M.[ScanRunId]) AS [ScanRunId]
    FROM [job].[SsrsJobMapping] AS M
    GROUP BY
        M.[InstanceId]
)
SELECT
    M.[SsrsJobMappingId],
    M.[ScanRunId],
    M.[InstanceId],
    I.[ServerInstance],
    E.[EnvironmentCode],
    M.[ReportServerDatabase],
    M.[SqlAgentJobId],
    M.[SqlAgentJobName],
    M.[ScheduleId],
    M.[SubscriptionId],
    M.[ReportId],
    M.[ReportName],
    M.[ReportPath],
    M.[SubscriptionDescription],
    M.[SubscriptionOwner],
    M.[DeliveryExtension],
    M.[LastStatus],
    M.[LastRunTime],
    M.[ScheduleName],
    M.[ScheduleNextRunTime],
    M.[ScheduleLastRunTime],
    M.[SsrsJobType],
    M.[FriendlyJobName],
    M.[CapturedAt]
FROM [job].[SsrsJobMapping] AS M
INNER JOIN LatestScan AS L
    ON L.[InstanceId] = M.[InstanceId]
   AND L.[ScanRunId] = M.[ScanRunId]
INNER JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = M.[InstanceId]
LEFT JOIN [dbo].[Environment] AS E
    ON E.[EnvironmentId] = I.[EnvironmentId];
GO

CREATE OR ALTER VIEW [report].[vSsrsJobMappingSummary]
AS
SELECT
    [EnvironmentCode],
    [ServerInstance],
    [ReportServerDatabase],
    COUNT(DISTINCT [SqlAgentJobId]) AS [SsrsJobCount],
    COUNT(DISTINCT [SubscriptionId]) AS [SubscriptionCount],
    COUNT(DISTINCT [ReportId]) AS [ReportCount],
    SUM
    (
        CASE
            WHEN NULLIF([ReportPath], N'') IS NULL
                THEN 1
            ELSE 0
        END
    ) AS [UnresolvedMappingCount],
    MAX([CapturedAt]) AS [CapturedAt]
FROM [report].[vCurrentSsrsJobMapping]
GROUP BY
    [EnvironmentCode],
    [ServerInstance],
    [ReportServerDatabase];
GO

CREATE OR ALTER VIEW [report].[vJobsWithFriendlyName]
AS
WITH SsrsAggregate AS
(
    SELECT
        M.[InstanceId],
        M.[SqlAgentJobId],

        MIN(M.[FriendlyJobName]) AS [FriendlyJobName],
        MIN(M.[ReportServerDatabase]) AS [ReportServerDatabase],
        MIN(M.[ReportName]) AS [ReportName],
        MIN(M.[ReportPath]) AS [ReportPath],
        MIN(M.[SubscriptionDescription]) AS [SubscriptionDescription],
        MIN(M.[SubscriptionOwner]) AS [SubscriptionOwner],
        MIN(M.[DeliveryExtension]) AS [DeliveryExtension],
        MAX(M.[LastStatus]) AS [SsrsLastStatus],
        MAX(M.[LastRunTime]) AS [SsrsLastRunTime],

        COUNT(*) AS [SsrsMappingCount],
        COUNT(DISTINCT M.[SubscriptionId]) AS [SsrsSubscriptionCount],
        COUNT(DISTINCT M.[ReportId]) AS [SsrsReportCount]
    FROM [report].[vCurrentSsrsJobMapping] AS M
    GROUP BY
        M.[InstanceId],
        M.[SqlAgentJobId]
)
SELECT
    J.*,

    CASE
        WHEN S.[SqlAgentJobId] IS NOT NULL
            THEN S.[FriendlyJobName]
        ELSE J.[JobName]
    END AS [FriendlyJobName],

    CASE
        WHEN S.[SqlAgentJobId] IS NOT NULL
            THEN N'SSRS'
        WHEN TRY_CONVERT(uniqueidentifier, J.[JobName]) IS NOT NULL
            THEN N'GUID_UNRESOLVED'
        ELSE N'SQL_AGENT'
    END AS [JobSource],

    S.[ReportServerDatabase],
    S.[ReportName],
    S.[ReportPath],
    S.[SubscriptionDescription],
    S.[SubscriptionOwner],
    S.[DeliveryExtension],
    S.[SsrsLastStatus],
    S.[SsrsLastRunTime],
    S.[SsrsMappingCount],
    S.[SsrsSubscriptionCount],
    S.[SsrsReportCount]
FROM [report].[vJobInventory] AS J
LEFT JOIN SsrsAggregate AS S
    ON S.[InstanceId] = J.[InstanceId]
   AND S.[SqlAgentJobId] = J.[JobId];
GO

CREATE OR ALTER VIEW [report].[vSsrsJobs]
AS
SELECT
    J.*
FROM [report].[vJobsWithFriendlyName] AS J
WHERE J.[JobSource] = N'SSRS';
GO

CREATE OR ALTER VIEW [report].[vUnresolvedGuidJobs]
AS
SELECT
    J.*
FROM [report].[vJobsWithFriendlyName] AS J
WHERE J.[JobSource] = N'GUID_UNRESOLVED';
GO

CREATE OR ALTER VIEW [report].[vSsrsJobDocumentationDetails]
AS
SELECT
    M.[InstanceId],
    M.[ServerInstance],
    M.[EnvironmentCode],
    M.[SqlAgentJobId] AS [JobId],
    M.[SqlAgentJobName] AS [TechnicalJobName],
    M.[FriendlyJobName],
    M.[ReportServerDatabase],
    M.[ReportName],
    M.[ReportPath],
    M.[SubscriptionId],
    M.[SubscriptionDescription],
    M.[SubscriptionOwner],
    M.[DeliveryExtension],
    M.[LastStatus],
    M.[LastRunTime],
    M.[ScheduleId],
    M.[ScheduleName],
    M.[ScheduleNextRunTime],
    M.[ScheduleLastRunTime],
    M.[SsrsJobType],
    M.[CapturedAt]
FROM [report].[vCurrentSsrsJobMapping] AS M;
GO

/*
    Aktualizacja nazwy rekomendacji. Nie zmieniamy samego mechanizmu findingu.
*/
UPDATE [audit].[ComplianceRule]
SET
    [Recommendation] =
        N'Utwórz automatyczną stronę techniczną joba, opublikuj ją w Confluence, uzupełnij właścicieli i krytyczność, a następnie zatwierdź dokumentację. Dla jobów SSRS użyj przyjaznej nazwy raportu i subskrypcji.'
WHERE [RuleCode] = 'JOB_NOT_DOCUMENTED';
GO

IF OBJECT_ID(N'[dbo].[usp_SetDescription]', N'P') IS NOT NULL
BEGIN
    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'job',
        @ObjectName = N'SsrsJobMapping',
        @ObjectType = 'TABLE',
        @Description = N'Mapowanie technicznych jobów SSRS o nazwach GUID na raporty, subskrypcje i harmonogramy.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vJobsWithFriendlyName',
        @ObjectType = 'VIEW',
        @Description = N'Joby SQL Server Agent z przyjazną nazwą SSRS, jeśli dostępne jest mapowanie.';

    EXEC [dbo].[usp_SetDescription]
        @SchemaName = N'report',
        @ObjectName = N'vUnresolvedGuidJobs',
        @ObjectType = 'VIEW',
        @Description = N'Joby z nazwą GUID, dla których nie znaleziono mapowania SSRS.';
END;
GO

SELECT *
FROM [report].[vSsrsJobMappingSummary]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [ReportServerDatabase];
GO

SELECT TOP (100)
    [ServerInstance],
    [JobName],
    [FriendlyJobName],
    [JobSource],
    [ReportPath],
    [SubscriptionDescription],
    [SubscriptionOwner],
    [SsrsLastStatus]
FROM [report].[vJobsWithFriendlyName]
WHERE [JobSource] IN
(
    N'SSRS',
    N'GUID_UNRESOLVED'
)
ORDER BY
    [ServerInstance],
    [FriendlyJobName];
GO
