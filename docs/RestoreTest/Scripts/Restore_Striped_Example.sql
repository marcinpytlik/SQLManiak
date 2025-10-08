-- Example: striped FULL restore (multiple backup files) to speed up throughput
-- Adjust file names to your environment. Requires that backups were created as striped.
RESTORE DATABASE [DemoDB_Test]
FROM
    DISK = N'D:\Backup\DemoDB_FULL_1.bak',
    DISK = N'D:\Backup\DemoDB_FULL_2.bak',
    DISK = N'D:\Backup\DemoDB_FULL_3.bak',
    DISK = N'D:\Backup\DemoDB_FULL_4.bak'
WITH MOVE N'DemoDB'     TO N'D:\SQLData\DemoDB_Test.mdf',
     MOVE N'DemoDB_log' TO N'D:\SQLLog\DemoDB_Test.ldf',
     REPLACE, NORECOVERY;
-- Follow with DIFF/LOG as needed (similar striping on LOG is supported).
