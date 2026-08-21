USE [DBACentralRepository];
GO

/* ============================================================================
   DBACentralRepository - Reporting Coverage Audit
   Purpose:
     Inventory repository areas, data objects and reporting objects so we can
     identify which functional areas already expose reporting and which do not.

   Notes:
     - This script audits the SQL layer only.
     - Grafana coverage is added by the companion PowerShell script.
   ============================================================================ */

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#Coverage') IS NOT NULL
    DROP TABLE #Coverage;

CREATE TABLE #Coverage
(
    Area                sysname        NOT NULL,
    DataObjectCount     int            NOT NULL,
    SnapshotTableCount  int            NOT NULL,
    ReportViewCount     int            NOT NULL,
    ReportProcCount     int            NOT NULL,
    ExampleDataObjects  nvarchar(max)  NULL,
    ExampleReportObjects nvarchar(max) NULL
);

WITH Areas AS
(
    SELECT v.Area
    FROM (VALUES
        ('audit'),
        ('backup'),
        ('capacity'),
        ('config'),
        ('db'),
        ('ha'),
        ('job'),
        ('maintenance'),
        ('patch'),
        ('perf'),
        ('security')
    ) v(Area)
),
DataObjects AS
(
    SELECT
        s.name AS Area,
        o.name AS ObjectName,
        o.type_desc,
        CASE
            WHEN o.type = 'U'
             AND (
                    o.name LIKE '%Snapshot%'
                 OR o.name LIKE '%History%'
                 OR o.name LIKE '%Run%'
                 OR o.name LIKE '%Finding%'
                 OR o.name LIKE '%Aggregate%'
                 OR o.name LIKE '%Batch%'
                 )
                THEN 1
            ELSE 0
        END AS IsSnapshotLike
    FROM sys.objects o
    JOIN sys.schemas s
      ON s.schema_id = o.schema_id
    WHERE
        o.is_ms_shipped = 0
        AND s.name IN
        (
            'audit','backup','capacity','config','db','ha','job',
            'maintenance','patch','perf','security'
        )
        AND o.type IN ('U','V','P')
),
ReportObjects AS
(
    SELECT
        o.name AS ObjectName,
        o.type,
        o.type_desc,
        LOWER(o.name) AS ObjectNameLower
    FROM sys.objects o
    JOIN sys.schemas s
      ON s.schema_id = o.schema_id
    WHERE
        o.is_ms_shipped = 0
        AND s.name = 'report'
        AND o.type IN ('V','P')
),
MappedReportObjects AS
(
    SELECT
        a.Area,
        r.ObjectName,
        r.type,
        r.type_desc
    FROM Areas a
    JOIN ReportObjects r
      ON
         (a.Area = 'job'         AND r.ObjectNameLower LIKE '%job%')
      OR (a.Area = 'backup'      AND r.ObjectNameLower LIKE '%backup%')
      OR (a.Area = 'capacity'    AND (r.ObjectNameLower LIKE '%capacity%'
                                  OR r.ObjectNameLower LIKE '%volume%'
                                  OR r.ObjectNameLower LIKE '%storage%'))
      OR (a.Area = 'config'      AND (r.ObjectNameLower LIKE '%config%'
                                  OR r.ObjectNameLower LIKE '%tempdb%'
                                  OR r.ObjectNameLower LIKE '%traceflag%'
                                  OR r.ObjectNameLower LIKE '%querystore%'
                                  OR r.ObjectNameLower LIKE '%linkedserver%'))
      OR (a.Area = 'db'          AND (r.ObjectNameLower LIKE '%database%'
                                  OR r.ObjectNameLower LIKE '%schema%'
                                  OR r.ObjectNameLower LIKE '%table%'))
      OR (a.Area = 'ha'          AND (r.ObjectNameLower LIKE '%ha%'
                                  OR r.ObjectNameLower LIKE '%availability%'
                                  OR r.ObjectNameLower LIKE '%replica%'))
      OR (a.Area = 'maintenance' AND (r.ObjectNameLower LIKE '%maintenance%'
                                  OR r.ObjectNameLower LIKE '%suspect%'))
      OR (a.Area = 'patch'       AND (r.ObjectNameLower LIKE '%patch%'
                                  OR r.ObjectNameLower LIKE '%build%'
                                  OR r.ObjectNameLower LIKE '%risk%'))
      OR (a.Area = 'perf'        AND (r.ObjectNameLower LIKE '%perf%'
                                  OR r.ObjectNameLower LIKE '%workload%'
                                  OR r.ObjectNameLower LIKE '%collector%'
                                  OR r.ObjectNameLower LIKE '%usage%'))
      OR (a.Area = 'security'    AND (r.ObjectNameLower LIKE '%security%'
                                  OR r.ObjectNameLower LIKE '%permission%'
                                  OR r.ObjectNameLower LIKE '%principal%'
                                  OR r.ObjectNameLower LIKE '%proxy%'
                                  OR r.ObjectNameLower LIKE '%credential%'
                                  OR r.ObjectNameLower LIKE '%mail%'))
      OR (a.Area = 'audit'       AND (r.ObjectNameLower LIKE '%audit%'
                                  OR r.ObjectNameLower LIKE '%compliance%'
                                  OR r.ObjectNameLower LIKE '%change%'))
)
INSERT #Coverage
(
    Area,
    DataObjectCount,
    SnapshotTableCount,
    ReportViewCount,
    ReportProcCount,
    ExampleDataObjects,
    ExampleReportObjects
)
SELECT
    a.Area,

    (
        SELECT COUNT(*)
        FROM DataObjects d
        WHERE d.Area = a.Area
    ) AS DataObjectCount,

    (
        SELECT COUNT(*)
        FROM DataObjects d
        WHERE d.Area = a.Area
          AND d.IsSnapshotLike = 1
    ) AS SnapshotTableCount,

    (
        SELECT COUNT(*)
        FROM MappedReportObjects r
        WHERE r.Area = a.Area
          AND r.type = 'V'
    ) AS ReportViewCount,

    (
        SELECT COUNT(*)
        FROM MappedReportObjects r
        WHERE r.Area = a.Area
          AND r.type = 'P'
    ) AS ReportProcCount,

    (
        SELECT STRING_AGG(CONVERT(nvarchar(max), d.ObjectName), ', ')
               WITHIN GROUP (ORDER BY d.ObjectName)
        FROM
        (
            SELECT TOP (8) ObjectName
            FROM DataObjects d2
            WHERE d2.Area = a.Area
            ORDER BY d2.ObjectName
        ) d
    ) AS ExampleDataObjects,

    (
        SELECT STRING_AGG(CONVERT(nvarchar(max), r.ObjectName), ', ')
               WITHIN GROUP (ORDER BY r.ObjectName)
        FROM
        (
            SELECT TOP (8) ObjectName
            FROM MappedReportObjects r2
            WHERE r2.Area = a.Area
            ORDER BY r2.ObjectName
        ) r
    ) AS ExampleReportObjects

FROM Areas a;


/* ============================================================================
   Result 1: Main SQL coverage matrix
   ============================================================================ */

SELECT
    Area,
    DataObjectCount,
    SnapshotTableCount,
    ReportViewCount,
    ReportProcCount,

    CASE
        WHEN DataObjectCount = 0
            THEN 'NO_DATA'
        WHEN ReportViewCount + ReportProcCount = 0
            THEN 'DATA_WITHOUT_REPORTING'
        ELSE 'REPORTING_EXISTS'
    END AS SqlCoverageStatus,

    ExampleDataObjects,
    ExampleReportObjects
FROM #Coverage
ORDER BY
    CASE
        WHEN DataObjectCount > 0 AND ReportViewCount + ReportProcCount = 0 THEN 1
        WHEN DataObjectCount > 0 THEN 2
        ELSE 3
    END,
    Area;


/* ============================================================================
   Result 2: Raw repository data objects
   ============================================================================ */

SELECT
    s.name AS SchemaName,
    o.name AS ObjectName,
    o.type_desc
FROM sys.objects o
JOIN sys.schemas s
  ON s.schema_id = o.schema_id
WHERE
    o.is_ms_shipped = 0
    AND s.name IN
    (
        'audit','backup','capacity','config','db','ha','job',
        'maintenance','patch','perf','security'
    )
    AND o.type IN ('U','V','P')
ORDER BY
    s.name,
    o.type_desc,
    o.name;


/* ============================================================================
   Result 3: All report objects
   ============================================================================ */

SELECT
    o.name AS ObjectName,
    o.type_desc
FROM sys.objects o
JOIN sys.schemas s
  ON s.schema_id = o.schema_id
WHERE
    o.is_ms_shipped = 0
    AND s.name = 'report'
    AND o.type IN ('V','P')
ORDER BY
    o.type_desc,
    o.name;


/* ============================================================================
   Result 4: Reporting gaps - priority candidates
   ============================================================================ */

SELECT
    Area,
    DataObjectCount,
    SnapshotTableCount,
    ReportViewCount,
    ReportProcCount,
    ExampleDataObjects
FROM #Coverage
WHERE
    DataObjectCount > 0
    AND ReportViewCount + ReportProcCount = 0
ORDER BY
    SnapshotTableCount DESC,
    DataObjectCount DESC,
    Area;


/* ============================================================================
   Result 5: Existing report-rich areas
   ============================================================================ */

SELECT
    Area,
    DataObjectCount,
    ReportViewCount,
    ReportProcCount,
    ExampleReportObjects
FROM #Coverage
WHERE ReportViewCount + ReportProcCount > 0
ORDER BY
    ReportViewCount + ReportProcCount DESC,
    Area;
GO
