USE [DBACentralRepository];
GO

/* ============================================================================
   DBACentralRepository
   Schema Change Diff Engine

   Purpose
   -------
   Compares consecutive successful SCHEMA collection runs and exposes:

     report.vSchemaScanPairs
     report.vDatabaseObjectChanges
     report.vDatabaseColumnChanges
     report.vDatabaseSchemaChanges
     report.vDatabaseSchemaChangeSummary

   Design notes
   ------------
   1. Only SUCCESS SCHEMA runs are paired.
   2. A database is compared only when db.DatabaseSchemaCollectionStatus
      reports SUCCESS for that database in BOTH scans.
      This prevents false mass DROP events caused by an incomplete collection.
   3. Object identity is based on:
        InstanceId + DatabaseName + SchemaName + ObjectName + ObjectType
      ObjectId is deliberately NOT used as the business key.
   4. Column identity is based on:
        InstanceId + DatabaseName + SchemaName + ObjectName + ColumnName
      A rename therefore appears as COLUMN_REMOVED + COLUMN_ADDED.
   5. DefinitionHash is used for programmable-object changes.
   6. ColumnSignatureHash is used for column-definition changes.
   ============================================================================ */


/* ============================================================================
   1. Consecutive successful SCHEMA runs
   ============================================================================ */

CREATE OR ALTER VIEW [report].[vSchemaScanPairs]
AS
WITH SuccessfulRuns AS
(
    SELECT
        sr.ScanRunId,
        sr.ScanStartedAt,
        sr.ScanFinishedAt,
        LAG(sr.ScanRunId) OVER
        (
            ORDER BY sr.ScanRunId
        ) AS PreviousScanRunId,
        LAG(sr.ScanStartedAt) OVER
        (
            ORDER BY sr.ScanRunId
        ) AS PreviousScanStartedAt,
        LAG(sr.ScanFinishedAt) OVER
        (
            ORDER BY sr.ScanRunId
        ) AS PreviousScanFinishedAt
    FROM dbo.ScanRun AS sr
    WHERE
        sr.ScanType = 'SCHEMA'
        AND sr.Status = 'SUCCESS'
)
SELECT
    ScanRunId AS CurrentScanRunId,
    PreviousScanRunId,
    ScanStartedAt AS CurrentScanStartedAt,
    ScanFinishedAt AS CurrentScanFinishedAt,
    PreviousScanStartedAt,
    PreviousScanFinishedAt
FROM SuccessfulRuns
WHERE PreviousScanRunId IS NOT NULL;
GO


/* ============================================================================
   2. Object changes
   ============================================================================ */

CREATE OR ALTER VIEW [report].[vDatabaseObjectChanges]
AS
WITH ComparableDatabases AS
(
    SELECT
        sp.CurrentScanRunId,
        sp.PreviousScanRunId,
        sp.CurrentScanStartedAt,
        sp.CurrentScanFinishedAt,
        sp.PreviousScanStartedAt,
        sp.PreviousScanFinishedAt,

        cur.InstanceId,
        cur.DatabaseName,

        COALESCE(cur.CompletedAt, cur.StartedAt) AS CurrentDatabaseCapturedAt,
        COALESCE(prev.CompletedAt, prev.StartedAt) AS PreviousDatabaseCapturedAt
    FROM report.vSchemaScanPairs AS sp
    INNER JOIN db.DatabaseSchemaCollectionStatus AS cur
        ON cur.ScanRunId = sp.CurrentScanRunId
       AND cur.CollectionStatus = 'SUCCESS'
    INNER JOIN db.DatabaseSchemaCollectionStatus AS prev
        ON prev.ScanRunId = sp.PreviousScanRunId
       AND prev.InstanceId = cur.InstanceId
       AND prev.DatabaseName = cur.DatabaseName
       AND prev.CollectionStatus = 'SUCCESS'
),
PreviousObjects AS
(
    SELECT
        cd.CurrentScanRunId,
        cd.PreviousScanRunId,
        cd.CurrentScanFinishedAt,
        cd.PreviousScanFinishedAt,

        o.InstanceId,
        o.DatabaseName,
        o.SchemaName,
        o.ObjectName,
        o.ObjectType,
        o.ObjectTypeDesc,
        o.ObjectId,
        o.CreateDate,
        o.ModifyDate,
        o.DefinitionHash,
        o.DefinitionText
    FROM ComparableDatabases AS cd
    INNER JOIN db.DatabaseObjectSnapshot AS o
        ON o.ScanRunId = cd.PreviousScanRunId
       AND o.InstanceId = cd.InstanceId
       AND o.DatabaseName = cd.DatabaseName
),
CurrentObjects AS
(
    SELECT
        cd.CurrentScanRunId,
        cd.PreviousScanRunId,
        cd.CurrentScanFinishedAt,
        cd.PreviousScanFinishedAt,

        o.InstanceId,
        o.DatabaseName,
        o.SchemaName,
        o.ObjectName,
        o.ObjectType,
        o.ObjectTypeDesc,
        o.ObjectId,
        o.CreateDate,
        o.ModifyDate,
        o.DefinitionHash,
        o.DefinitionText
    FROM ComparableDatabases AS cd
    INNER JOIN db.DatabaseObjectSnapshot AS o
        ON o.ScanRunId = cd.CurrentScanRunId
       AND o.InstanceId = cd.InstanceId
       AND o.DatabaseName = cd.DatabaseName
)
SELECT
    COALESCE(c.CurrentScanRunId, p.CurrentScanRunId) AS CurrentScanRunId,
    COALESCE(c.PreviousScanRunId, p.PreviousScanRunId) AS PreviousScanRunId,

    COALESCE(c.CurrentScanFinishedAt, p.CurrentScanFinishedAt) AS ChangeDetectedAt,
    COALESCE(c.PreviousScanFinishedAt, p.PreviousScanFinishedAt) AS PreviousSnapshotAt,

    COALESCE(c.InstanceId, p.InstanceId) AS InstanceId,
    COALESCE(c.DatabaseName, p.DatabaseName) AS DatabaseName,
    COALESCE(c.SchemaName, p.SchemaName) AS SchemaName,
    COALESCE(c.ObjectName, p.ObjectName) AS ObjectName,
    COALESCE(c.ObjectType, p.ObjectType) AS ObjectType,
    COALESCE(c.ObjectTypeDesc, p.ObjectTypeDesc) AS ObjectTypeDesc,

    CASE
        WHEN p.ObjectName IS NULL THEN 'OBJECT_ADDED'
        WHEN c.ObjectName IS NULL THEN 'OBJECT_REMOVED'
        ELSE 'OBJECT_CHANGED'
    END AS ChangeType,

    p.ObjectId AS PreviousObjectId,
    c.ObjectId AS CurrentObjectId,

    p.CreateDate AS PreviousCreateDate,
    c.CreateDate AS CurrentCreateDate,

    p.ModifyDate AS PreviousModifyDate,
    c.ModifyDate AS CurrentModifyDate,

    p.DefinitionHash AS PreviousDefinitionHash,
    c.DefinitionHash AS CurrentDefinitionHash,

    p.DefinitionText AS PreviousDefinitionText,
    c.DefinitionText AS CurrentDefinitionText
FROM PreviousObjects AS p
FULL OUTER JOIN CurrentObjects AS c
    ON c.CurrentScanRunId = p.CurrentScanRunId
   AND c.PreviousScanRunId = p.PreviousScanRunId
   AND c.InstanceId = p.InstanceId
   AND c.DatabaseName = p.DatabaseName
   AND c.SchemaName = p.SchemaName
   AND c.ObjectName = p.ObjectName
   AND c.ObjectType = p.ObjectType
WHERE
       p.ObjectName IS NULL
    OR c.ObjectName IS NULL
    OR ISNULL(p.DefinitionHash, 0x) <> ISNULL(c.DefinitionHash, 0x);
GO


/* ============================================================================
   3. Column changes
   ============================================================================ */

CREATE OR ALTER VIEW [report].[vDatabaseColumnChanges]
AS
WITH ComparableDatabases AS
(
    SELECT
        sp.CurrentScanRunId,
        sp.PreviousScanRunId,
        sp.CurrentScanStartedAt,
        sp.CurrentScanFinishedAt,
        sp.PreviousScanStartedAt,
        sp.PreviousScanFinishedAt,

        cur.InstanceId,
        cur.DatabaseName
    FROM report.vSchemaScanPairs AS sp
    INNER JOIN db.DatabaseSchemaCollectionStatus AS cur
        ON cur.ScanRunId = sp.CurrentScanRunId
       AND cur.CollectionStatus = 'SUCCESS'
    INNER JOIN db.DatabaseSchemaCollectionStatus AS prev
        ON prev.ScanRunId = sp.PreviousScanRunId
       AND prev.InstanceId = cur.InstanceId
       AND prev.DatabaseName = cur.DatabaseName
       AND prev.CollectionStatus = 'SUCCESS'
),
PreviousColumns AS
(
    SELECT
        cd.CurrentScanRunId,
        cd.PreviousScanRunId,
        cd.CurrentScanFinishedAt,
        cd.PreviousScanFinishedAt,

        c.InstanceId,
        c.DatabaseName,
        c.SchemaName,
        c.ObjectName,
        c.ObjectType,
        c.ColumnId,
        c.ColumnName,
        c.DataTypeName,
        c.MaxLength,
        c.PrecisionValue,
        c.ScaleValue,
        c.IsNullable,
        c.IsIdentity,
        c.IsComputed,
        c.CollationName,
        c.DefaultDefinition,
        c.ComputedDefinition,
        c.ColumnSignatureHash
    FROM ComparableDatabases AS cd
    INNER JOIN db.DatabaseColumnSnapshot AS c
        ON c.ScanRunId = cd.PreviousScanRunId
       AND c.InstanceId = cd.InstanceId
       AND c.DatabaseName = cd.DatabaseName
),
CurrentColumns AS
(
    SELECT
        cd.CurrentScanRunId,
        cd.PreviousScanRunId,
        cd.CurrentScanFinishedAt,
        cd.PreviousScanFinishedAt,

        c.InstanceId,
        c.DatabaseName,
        c.SchemaName,
        c.ObjectName,
        c.ObjectType,
        c.ColumnId,
        c.ColumnName,
        c.DataTypeName,
        c.MaxLength,
        c.PrecisionValue,
        c.ScaleValue,
        c.IsNullable,
        c.IsIdentity,
        c.IsComputed,
        c.CollationName,
        c.DefaultDefinition,
        c.ComputedDefinition,
        c.ColumnSignatureHash
    FROM ComparableDatabases AS cd
    INNER JOIN db.DatabaseColumnSnapshot AS c
        ON c.ScanRunId = cd.CurrentScanRunId
       AND c.InstanceId = cd.InstanceId
       AND c.DatabaseName = cd.DatabaseName
)
SELECT
    COALESCE(c.CurrentScanRunId, p.CurrentScanRunId) AS CurrentScanRunId,
    COALESCE(c.PreviousScanRunId, p.PreviousScanRunId) AS PreviousScanRunId,

    COALESCE(c.CurrentScanFinishedAt, p.CurrentScanFinishedAt) AS ChangeDetectedAt,
    COALESCE(c.PreviousScanFinishedAt, p.PreviousScanFinishedAt) AS PreviousSnapshotAt,

    COALESCE(c.InstanceId, p.InstanceId) AS InstanceId,
    COALESCE(c.DatabaseName, p.DatabaseName) AS DatabaseName,
    COALESCE(c.SchemaName, p.SchemaName) AS SchemaName,
    COALESCE(c.ObjectName, p.ObjectName) AS ObjectName,
    COALESCE(c.ObjectType, p.ObjectType) AS ObjectType,
    COALESCE(c.ColumnName, p.ColumnName) AS ColumnName,

    CASE
        WHEN p.ColumnName IS NULL THEN 'COLUMN_ADDED'
        WHEN c.ColumnName IS NULL THEN 'COLUMN_REMOVED'
        ELSE 'COLUMN_CHANGED'
    END AS ChangeType,

    p.ColumnId AS PreviousColumnId,
    c.ColumnId AS CurrentColumnId,

    p.DataTypeName AS PreviousDataTypeName,
    c.DataTypeName AS CurrentDataTypeName,

    p.MaxLength AS PreviousMaxLength,
    c.MaxLength AS CurrentMaxLength,

    p.PrecisionValue AS PreviousPrecisionValue,
    c.PrecisionValue AS CurrentPrecisionValue,

    p.ScaleValue AS PreviousScaleValue,
    c.ScaleValue AS CurrentScaleValue,

    p.IsNullable AS PreviousIsNullable,
    c.IsNullable AS CurrentIsNullable,

    p.IsIdentity AS PreviousIsIdentity,
    c.IsIdentity AS CurrentIsIdentity,

    p.IsComputed AS PreviousIsComputed,
    c.IsComputed AS CurrentIsComputed,

    p.CollationName AS PreviousCollationName,
    c.CollationName AS CurrentCollationName,

    p.DefaultDefinition AS PreviousDefaultDefinition,
    c.DefaultDefinition AS CurrentDefaultDefinition,

    p.ComputedDefinition AS PreviousComputedDefinition,
    c.ComputedDefinition AS CurrentComputedDefinition,

    p.ColumnSignatureHash AS PreviousColumnSignatureHash,
    c.ColumnSignatureHash AS CurrentColumnSignatureHash
FROM PreviousColumns AS p
FULL OUTER JOIN CurrentColumns AS c
    ON c.CurrentScanRunId = p.CurrentScanRunId
   AND c.PreviousScanRunId = p.PreviousScanRunId
   AND c.InstanceId = p.InstanceId
   AND c.DatabaseName = p.DatabaseName
   AND c.SchemaName = p.SchemaName
   AND c.ObjectName = p.ObjectName
   AND c.ColumnName = p.ColumnName
WHERE
       p.ColumnName IS NULL
    OR c.ColumnName IS NULL
    OR p.ColumnSignatureHash <> c.ColumnSignatureHash;
GO


/* ============================================================================
   4. Unified schema changes
   ============================================================================ */

CREATE OR ALTER VIEW [report].[vDatabaseSchemaChanges]
AS

SELECT
    oc.CurrentScanRunId,
    oc.PreviousScanRunId,
    oc.ChangeDetectedAt,
    oc.PreviousSnapshotAt,

    oc.InstanceId,
    oc.DatabaseName,
    oc.SchemaName,
    oc.ObjectName,

    CAST(NULL AS sysname) AS ColumnName,

    CAST('OBJECT' AS varchar(10)) AS ChangeScope,
    oc.ChangeType,

    oc.ObjectType,
    oc.ObjectTypeDesc,

    CAST(NULL AS sysname) AS PreviousDataTypeName,
    CAST(NULL AS sysname) AS CurrentDataTypeName,

    oc.PreviousModifyDate,
    oc.CurrentModifyDate,

    oc.PreviousDefinitionHash,
    oc.CurrentDefinitionHash,

    oc.PreviousDefinitionText,
    oc.CurrentDefinitionText

FROM report.vDatabaseObjectChanges AS oc

UNION ALL

SELECT
    cc.CurrentScanRunId,
    cc.PreviousScanRunId,
    cc.ChangeDetectedAt,
    cc.PreviousSnapshotAt,

    cc.InstanceId,
    cc.DatabaseName,
    cc.SchemaName,
    cc.ObjectName,

    cc.ColumnName,

    CAST('COLUMN' AS varchar(10)) AS ChangeScope,
    cc.ChangeType,

    cc.ObjectType,
    CAST(NULL AS nvarchar(120)) AS ObjectTypeDesc,

    cc.PreviousDataTypeName,
    cc.CurrentDataTypeName,

    CAST(NULL AS datetime) AS PreviousModifyDate,
    CAST(NULL AS datetime) AS CurrentModifyDate,

    CAST(NULL AS varbinary(32)) AS PreviousDefinitionHash,
    CAST(NULL AS varbinary(32)) AS CurrentDefinitionHash,

    CAST(NULL AS nvarchar(max)) AS PreviousDefinitionText,
    CAST(NULL AS nvarchar(max)) AS CurrentDefinitionText

FROM report.vDatabaseColumnChanges AS cc;
GO


/* ============================================================================
   5. Summary for Grafana
   ============================================================================ */

CREATE OR ALTER VIEW [report].[vDatabaseSchemaChangeSummary]
AS
SELECT
    CurrentScanRunId,
    PreviousScanRunId,
    ChangeDetectedAt,

    InstanceId,
    DatabaseName,

    ChangeScope,
    ChangeType,

    COUNT_BIG(*) AS ChangeCount
FROM report.vDatabaseSchemaChanges
GROUP BY
    CurrentScanRunId,
    PreviousScanRunId,
    ChangeDetectedAt,
    InstanceId,
    DatabaseName,
    ChangeScope,
    ChangeType;
GO


/* ============================================================================
   6. Verification
   ============================================================================ */

PRINT 'Schema scan pairs';
SELECT *
FROM report.vSchemaScanPairs
ORDER BY CurrentScanRunId DESC;
GO

PRINT 'Object changes';
SELECT TOP (100)
    CurrentScanRunId,
    PreviousScanRunId,
    ChangeDetectedAt,
    DatabaseName,
    SchemaName,
    ObjectName,
    ObjectTypeDesc,
    ChangeType
FROM report.vDatabaseObjectChanges
ORDER BY
    CurrentScanRunId DESC,
    DatabaseName,
    SchemaName,
    ObjectName;
GO

PRINT 'Column changes';
SELECT TOP (200)
    CurrentScanRunId,
    PreviousScanRunId,
    ChangeDetectedAt,
    DatabaseName,
    SchemaName,
    ObjectName,
    ColumnName,
    ChangeType,
    PreviousDataTypeName,
    CurrentDataTypeName
FROM report.vDatabaseColumnChanges
ORDER BY
    CurrentScanRunId DESC,
    DatabaseName,
    SchemaName,
    ObjectName,
    ColumnName;
GO

PRINT 'Unified schema changes';
SELECT TOP (200)
    CurrentScanRunId,
    PreviousScanRunId,
    ChangeDetectedAt,
    DatabaseName,
    SchemaName,
    ObjectName,
    ColumnName,
    ChangeScope,
    ChangeType
FROM report.vDatabaseSchemaChanges
ORDER BY
    CurrentScanRunId DESC,
    DatabaseName,
    SchemaName,
    ObjectName,
    ColumnName;
GO

PRINT 'Schema change summary';
SELECT *
FROM report.vDatabaseSchemaChangeSummary
ORDER BY
    CurrentScanRunId DESC,
    DatabaseName,
    ChangeScope,
    ChangeType;
GO


/* ============================================================================
   Expected controlled test result

   For the test table:

       AdventureWorks2022.dbo.SchemaChangeDemo

   created between SCHEMA ScanRunId 2 and ScanRunId 4, the views should report:

       OBJECT_ADDED  dbo.SchemaChangeDemo

   and column changes such as:

       COLUMN_ADDED  dbo.SchemaChangeDemo.Id
       COLUMN_ADDED  dbo.SchemaChangeDemo.Name
       COLUMN_ADDED  dbo.SchemaChangeDemo.CreatedAt

   ============================================================================ */
