USE SqlAnomalyWatcherDb;
GO

IF COL_LENGTH('dbo.AnomalyScore', 'TopReason1') IS NULL
BEGIN
    ALTER TABLE dbo.AnomalyScore
    ADD TopReason1 nvarchar(400) NULL;
END
GO

IF COL_LENGTH('dbo.AnomalyScore', 'TopReason2') IS NULL
BEGIN
    ALTER TABLE dbo.AnomalyScore
    ADD TopReason2 nvarchar(400) NULL;
END
GO

IF COL_LENGTH('dbo.AnomalyScore', 'TopReason3') IS NULL
BEGIN
    ALTER TABLE dbo.AnomalyScore
    ADD TopReason3 nvarchar(400) NULL;
END
GO