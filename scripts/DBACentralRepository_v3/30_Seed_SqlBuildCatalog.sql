USE [DBACentralRepository];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

MERGE [patch].[SqlBuildCatalog] AS tgt
USING
(
    SELECT
        16 AS MajorVersion,
        N'16.0.4262.2' AS ProductVersion,
        N'SQL Server 2022' AS ProductName,
        'CU/GDR' AS ServicingModel,
        'SECURITY' AS ReleaseType,
        N'16.0.4262.2' AS ReleaseName,
        CONVERT(date,'2026-07-14') AS ReleaseDate,
        CONVERT(bit,0) AS IsRecommended,
        CONVERT(date,NULL) AS SupportEndDate,
        N'https://learn.microsoft.com/troubleshoot/sql/releases/sqlserver-2022/build-versions' AS SourceUrl
    UNION ALL
    SELECT
        16,
        N'16.0.4265.3',
        N'SQL Server 2022',
        'CU',
        'CU',
        N'CU26',
        CONVERT(date,'2026-07-16'),
        CONVERT(bit,1),
        CONVERT(date,NULL),
        N'https://learn.microsoft.com/troubleshoot/sql/releases/sqlserver-2022/build-versions'
) AS src
ON tgt.MajorVersion=src.MajorVersion
AND tgt.ProductVersion=src.ProductVersion
WHEN MATCHED THEN UPDATE SET
    ProductName=src.ProductName,
    ServicingModel=src.ServicingModel,
    ReleaseType=src.ReleaseType,
    ReleaseName=src.ReleaseName,
    ReleaseDate=src.ReleaseDate,
    IsRecommended=src.IsRecommended,
    SupportEndDate=src.SupportEndDate,
    SourceUrl=src.SourceUrl
WHEN NOT MATCHED THEN
INSERT
(
    MajorVersion,ProductVersion,ProductName,ServicingModel,ReleaseType,
    ReleaseName,ReleaseDate,IsRecommended,SupportEndDate,SourceUrl
)
VALUES
(
    src.MajorVersion,src.ProductVersion,src.ProductName,src.ServicingModel,src.ReleaseType,
    src.ReleaseName,src.ReleaseDate,src.IsRecommended,src.SupportEndDate,src.SourceUrl
);
GO

UPDATE patch.SqlBuildCatalog
SET IsRecommended=CASE WHEN ProductVersion=N'16.0.4265.3' THEN 1 ELSE 0 END
WHERE MajorVersion=16;
GO

SELECT *
FROM patch.SqlBuildCatalog
WHERE MajorVersion=16
ORDER BY ReleaseDate,SqlBuildCatalogId;
GO
