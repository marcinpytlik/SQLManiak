USE master;
GO

CREATE DATABASE SMBTest on
(Name='SMBTest_data', Filename='\\MIA-SQL\SmbShare\SMBTest_data.mdf')
LOG ON
(Name='SMBTest_log', Filename='\\MIA-SQL\SmbShare\SMBTest_log.ldf')
GO
