USE [DBACentralRepository];
GO

CREATE OR ALTER PROCEDURE [patch].[usp_AssessCurrentBuilds]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @AssessedAt datetime2(0)=SYSDATETIME();

    ;WITH InstanceVersion AS
    (
        SELECT
            i.InstanceId,
            i.ServerInstance,
            i.ProductVersion,
            i.ProductMajorVersion,
            CONVERT(bigint,
                COALESCE(TRY_CONVERT(bigint,PARSENAME(i.ProductVersion,4)),0)*1000000000000000 +
                COALESCE(TRY_CONVERT(bigint,PARSENAME(i.ProductVersion,3)),0)*1000000000000 +
                COALESCE(TRY_CONVERT(bigint,PARSENAME(i.ProductVersion,2)),0)*1000000 +
                COALESCE(TRY_CONVERT(bigint,PARSENAME(i.ProductVersion,1)),0)
            ) AS CurrentVersionKey
        FROM dbo.Instance i
        WHERE i.IsEnabled=1
    ),
    Recommended AS
    (
        SELECT
            c.MajorVersion,
            c.ProductVersion,
            c.ReleaseName,
            c.ReleaseDate,
            c.SupportEndDate,
            CONVERT(bigint,
                COALESCE(TRY_CONVERT(bigint,PARSENAME(c.ProductVersion,4)),0)*1000000000000000 +
                COALESCE(TRY_CONVERT(bigint,PARSENAME(c.ProductVersion,3)),0)*1000000000000 +
                COALESCE(TRY_CONVERT(bigint,PARSENAME(c.ProductVersion,2)),0)*1000000 +
                COALESCE(TRY_CONVERT(bigint,PARSENAME(c.ProductVersion,1)),0)
            ) AS RecommendedVersionKey,
            ROW_NUMBER() OVER
            (
                PARTITION BY c.MajorVersion
                ORDER BY c.ReleaseDate DESC,c.SqlBuildCatalogId DESC
            ) AS rn
        FROM patch.SqlBuildCatalog c
        WHERE c.IsRecommended=1
    ),
    AssessmentSource AS
    (
        SELECT
            iv.InstanceId,
            iv.ServerInstance,
            iv.ProductVersion AS CurrentVersion,
            iv.CurrentVersionKey,
            r.ProductVersion AS RecommendedVersion,
            r.RecommendedVersionKey,
            r.ReleaseName,
            r.SupportEndDate,
            CASE
                WHEN r.ProductVersion IS NULL THEN 'UNKNOWN'
                WHEN r.SupportEndDate IS NOT NULL AND r.SupportEndDate<CONVERT(date,@AssessedAt) THEN 'EOS'
                WHEN iv.CurrentVersionKey=r.RecommendedVersionKey THEN 'CURRENT'
                WHEN iv.CurrentVersionKey<r.RecommendedVersionKey THEN 'OUTDATED'
                ELSE 'AHEAD'
            END AS AssessmentStatus
        FROM InstanceVersion iv
        LEFT JOIN Recommended r
          ON r.MajorVersion=iv.ProductMajorVersion
         AND r.rn=1
    )
    INSERT patch.PatchAssessment
    (
        InstanceId,AssessedAt,CurrentVersion,RecommendedVersion,
        AssessmentStatus,MissingReleaseCount,IsEndOfSupport,Notes
    )
    SELECT
        a.InstanceId,
        @AssessedAt,
        a.CurrentVersion,
        a.RecommendedVersion,
        a.AssessmentStatus,
        CASE
            WHEN a.RecommendedVersion IS NULL THEN NULL
            WHEN a.CurrentVersionKey>=a.RecommendedVersionKey THEN 0
            ELSE
            (
                SELECT COUNT(*)
                FROM patch.SqlBuildCatalog c
                CROSS APPLY
                (
                    SELECT CONVERT(bigint,
                        COALESCE(TRY_CONVERT(bigint,PARSENAME(c.ProductVersion,4)),0)*1000000000000000 +
                        COALESCE(TRY_CONVERT(bigint,PARSENAME(c.ProductVersion,3)),0)*1000000000000 +
                        COALESCE(TRY_CONVERT(bigint,PARSENAME(c.ProductVersion,2)),0)*1000000 +
                        COALESCE(TRY_CONVERT(bigint,PARSENAME(c.ProductVersion,1)),0)
                    ) AS CatalogVersionKey
                ) vk
                WHERE c.MajorVersion=
                (
                    SELECT ProductMajorVersion
                    FROM dbo.Instance
                    WHERE InstanceId=a.InstanceId
                )
                AND vk.CatalogVersionKey>a.CurrentVersionKey
                AND vk.CatalogVersionKey<=a.RecommendedVersionKey
            )
        END,
        CONVERT(bit,CASE
            WHEN a.SupportEndDate IS NOT NULL AND a.SupportEndDate<CONVERT(date,@AssessedAt) THEN 1
            ELSE 0 END),
        CONVERT(nvarchar(max),CASE
            WHEN a.RecommendedVersion IS NULL
                THEN N'No recommended build is defined in patch.SqlBuildCatalog for this major version.'
            WHEN a.AssessmentStatus='CURRENT'
                THEN N'Instance is on the recommended build.'
            WHEN a.AssessmentStatus='OUTDATED'
                THEN CONCAT(N'Instance is behind recommended build ',a.RecommendedVersion,
                            CASE WHEN a.ReleaseName IS NULL THEN N'' ELSE CONCAT(N' (',a.ReleaseName,N')') END,N'.')
            WHEN a.AssessmentStatus='AHEAD'
                THEN N'Instance build is newer than the build currently marked as recommended.'
            WHEN a.AssessmentStatus='EOS'
                THEN N'The catalog marks this SQL Server major version as out of support.'
        END)
    FROM AssessmentSource a;

    SELECT
        i.ServerInstance,
        pa.AssessedAt,
        pa.CurrentVersion,
        pa.RecommendedVersion,
        pa.AssessmentStatus,
        pa.MissingReleaseCount,
        pa.IsEndOfSupport,
        pa.Notes
    FROM patch.PatchAssessment pa
    JOIN dbo.Instance i ON i.InstanceId=pa.InstanceId
    WHERE pa.AssessedAt=@AssessedAt
    ORDER BY i.ServerInstance;
END;
GO

EXEC patch.usp_AssessCurrentBuilds;
GO

SELECT TOP (50)
    pa.PatchAssessmentId,
    i.ServerInstance,
    pa.AssessedAt,
    pa.CurrentVersion,
    pa.RecommendedVersion,
    pa.AssessmentStatus,
    pa.MissingReleaseCount,
    pa.IsEndOfSupport,
    pa.Notes
FROM patch.PatchAssessment pa
JOIN dbo.Instance i ON i.InstanceId=pa.InstanceId
ORDER BY pa.AssessedAt DESC,pa.PatchAssessmentId DESC;
GO

SELECT *
FROM report.vGrafanaPatchStatus
ORDER BY ServerInstance;
GO
