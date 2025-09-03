-- Try to restore an encrypted backup 

RESTORE DATABASE AdventureWorks
FROM DISK='D:\Demofiles\Mod07\EncryptedBackup.bak' WITH REPLACE,
MOVE N'AdventureWorks2016CTP3_Data' TO 'D:\Demofiles\Mod07\AdventureWorks_Data.mdf',
MOVE 'AdventureWorks2016CTP3_Log' TO 'D:\Demofiles\Mod07\AdventureWorks_Log.ldf',
MOVE 'AdventureWorks2016CTP3_mod' TO 'D:\Demofiles\Mod07\AdventureWorks_mod.ldf'

-- Create a database master key for master 

USE Master
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd'

-- Import the backed up certificate

CREATE CERTIFICATE EncryptedBackup FROM FILE ='D:\Demofiles\Mod07\EncryptedBackupCert.cer'
WITH PRIVATE KEY (
DECRYPTION BY PASSWORD = 'Pa$$w0rd'
, FILE = 'D:\Demofiles\Mod07\EncryptedBackupCert.pky'
)

-- Restore the encrypted database

RESTORE DATABASE AdventureWorks
FROM DISK='D:\Demofiles\Mod07\EncryptedBackup.bak' WITH REPLACE,
MOVE N'AdventureWorks2016CTP3_Data' TO 'D:\Demofiles\Mod07\AdventureWorks_Data.mdf',
MOVE 'AdventureWorks2016CTP3_Log' TO 'D:\Demofiles\Mod07\AdventureWorks_Log.ldf',
MOVE 'AdventureWorks2016CTP3_mod' TO 'D:\Demofiles\Mod07\AdventureWorks_mod.ldf'