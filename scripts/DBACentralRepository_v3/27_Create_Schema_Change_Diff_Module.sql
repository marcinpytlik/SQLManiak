SELECT
    SYSUTCDATETIME() AS CurrentUtc,
    DATEADD(day, -30, SYSUTCDATETIME()) AS FromUtc,
    MIN(ChangeDetectedAtUtc) AS MinChangeUtc,
    MAX(ChangeDetectedAtUtc) AS MaxChangeUtc,
    COUNT(*) AS ChangeCount
FROM report.vDatabaseSchemaChanges
WHERE ChangeDetectedAtUtc
      BETWEEN DATEADD(day, -30, SYSUTCDATETIME())
          AND SYSUTCDATETIME();