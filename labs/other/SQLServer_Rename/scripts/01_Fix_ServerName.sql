/* scripts/01_Fix_ServerName.sql
   Idempotentna naprawa wewnętrznej nazwy serwera SQL po renamie hosta.
   Działa dla instancji domyślnej i nazwanej.
*/
SET NOCOUNT ON;

DECLARE @Current sysname = @@SERVERNAME;
DECLARE @Target  sysname = CAST(SERVERPROPERTY('ServerName') AS sysname); -- oczekiwane: HOST lub HOST\INSTANCJA

PRINT CONCAT('@@SERVERNAME = ', COALESCE(@Current,'<NULL>'), ' ; Target = ', @Target);

IF @Current IS NULL OR @Current <> @Target
BEGIN
    IF @Current IS NOT NULL
    BEGIN
        PRINT CONCAT('Dropping old server name: ', @Current);
        EXEC sys.sp_dropserver @server = @Current;
    END

    PRINT CONCAT('Adding local server name: ', @Target);
    EXEC sys.sp_addserver @server = @Target, @local = 'local';

    PRINT 'Zmieniono metadane. **Zrestartuj usługę SQL Server**, aby @@SERVERNAME przyjął nową wartość.';
END
ELSE
BEGIN
    PRINT 'OK: @@SERVERNAME już zgadza się z ServerProperty(ServerName). Restart niepotrzebny.';
END
