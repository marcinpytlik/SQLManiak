USE AdventureWorks2022;  -- zmień jeśli trzeba
GO

/* Resign wszystkich procedur w schemacie dba certyfikatem dmv_cert */
CREATE OR ALTER PROC dba.usp_resign_all_dba_procs
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
    BEGIN
        RAISERROR('Brak certyfikatu dmv_cert w tej bazie.', 11, 1);
        RETURN;
    END

    DECLARE @sch sysname, @obj sysname, @sql nvarchar(max);

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.name, o.name
        FROM sys.objects o
        JOIN sys.schemas s ON s.schema_id = o.schema_id
        WHERE s.name = N'dba' AND o.type = 'P';  -- tylko procedury

    OPEN c;
    FETCH NEXT FROM c INTO @sch, @obj;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            SET @sql = N'DROP SIGNATURE FROM OBJECT::' + QUOTENAME(@sch) + N'.' + QUOTENAME(@obj) +
                       N' BY CERTIFICATE dmv_cert;';
            EXEC (@sql);
        END TRY BEGIN CATCH END CATCH;

        SET @sql = N'ADD SIGNATURE TO OBJECT::' + QUOTENAME(@sch) + N'.' + QUOTENAME(@obj) +
                   N' BY CERTIFICATE dmv_cert;';
        EXEC (@sql);

        FETCH NEXT FROM c INTO @sch, @obj;
    END
    CLOSE c; DEALLOCATE c;

    PRINT 'Podpisy odświeżone.';
END;
GO

/* Podgląd: które obiekty w dba są podpisane */
SELECT o.name AS object_name, cp.* 
FROM sys.crypt_properties cp
JOIN sys.objects o ON o.object_id = cp.major_id
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name = N'dba' AND cp.class_desc = 'OBJECT_OR_COLUMN';
