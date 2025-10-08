-- Point-in-time restore (STOPAT). Odtwarzamy do wskazanego czasu.
-- Przykładowy timestamp: '2025-10-08T08:15:00'
RESTORE LOG [DemoDB_Test]
FROM DISK = N'D:\Backup\DemoDB_LOG_LAST.trn'
WITH STOPAT = '2025-10-08T08:15:00',
     RECOVERY;
