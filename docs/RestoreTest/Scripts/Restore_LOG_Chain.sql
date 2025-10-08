-- Apply a sequence of LOG backups (example: latest two)
-- Zmień ścieżki/nazwy plików zgodnie z rzeczywistością.
RESTORE LOG [DemoDB_Test]
FROM DISK = N'D:\Backup\DemoDB_LOG_1.trn'
WITH NORECOVERY;

RESTORE LOG [DemoDB_Test]
FROM DISK = N'D:\Backup\DemoDB_LOG_2.trn'
WITH RECOVERY; -- końcowe RECOVERY
