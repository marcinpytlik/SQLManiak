-- 60-Verification.sql
-- Szybkie testy po migracji.
SELECT 'DynamicsAX version' AS What, @@VERSION AS Value;
SELECT DB_NAME() AS DBName, compatibility_level FROM sys.databases WHERE name IN ('DynamicsAX','DynamicsAX_model');

-- SSRS ExecutionLog3
IF DB_ID('ReportServer') IS NOT NULL
  SELECT TOP(50) TimeStart, ItemPath, Status, ByteCount, RowCount, TimeRendering, Source
  FROM ReportServer.dbo.ExecutionLog3 ORDER BY TimeStart DESC;
