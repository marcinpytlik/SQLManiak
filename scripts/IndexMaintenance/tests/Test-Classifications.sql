/* Test in isolated test repository database only; never run on production repository.
 Tests the classification logic without requiring a remote collector. */
USE [SQLManiakIndexMaintenance];
GO
DECLARE @data TABLE (Pages bigint,Frag float,Density float,Expected varchar(32));
INSERT @data VALUES
 (2000,5.0,95.0,'NO_ACTION'),
 (2000,15.0,95.0,'REORGANIZE_CANDIDATE'),
 (2000,45.0,95.0,'REBUILD_CANDIDATE'),
 (150000,35.0,95.0,'REVIEW'),
 (2000,5.0,60.0,'REVIEW'),
 (2000,NULL,NULL,'REVIEW');
SELECT Pages,Frag,Density,Expected,
 CASE WHEN Frag IS NULL THEN 'REVIEW'
 WHEN Pages>=100000 AND Frag>=30 THEN 'REVIEW'
 WHEN Density<70 THEN 'REVIEW'
 WHEN Frag>=30 THEN 'REBUILD_CANDIDATE'
 WHEN Frag>=10 THEN 'REORGANIZE_CANDIDATE'
 ELSE 'NO_ACTION' END Actual
FROM @data;
GO
