-- scripts/02_repro_vlf_explosion.sql
-- Generujemy wiele małych autogrow, aby stworzyć setki VLF.

USE VLF_Lab;
GO
SET NOCOUNT ON;

DECLARE @i int = 0;
WHILE (@i < 2000)
BEGIN
    BEGIN TRAN;
        INSERT dbo.BigTxn DEFAULT VALUES;
    COMMIT;
    SET @i += 1;
END
GO

-- Pokaż VLF i ich liczbę (nowoczesny DMV)
SELECT file_id, vlf_begin_offset, vlf_size_mb, vlf_sequence_number, vlf_active
FROM sys.dm_db_log_info(DB_ID())
ORDER BY file_id, vlf_begin_offset;

SELECT COUNT(*) AS VLF_Count
FROM sys.dm_db_log_info(DB_ID());
