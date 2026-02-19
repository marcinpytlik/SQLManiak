/* Quick errorlog scan (last N days) for important patterns.
   Requires xp_readerrorlog access (typically sysadmin).
*/
SET NOCOUNT ON;

DECLARE @days int = 2;

DECLARE @start datetime = DATEADD(d, -1 * @days, GETDATE());
DECLARE @end   datetime = GETDATE();

-- patterns
DECLARE @patterns TABLE (rn int identity(1,1), pat nvarchar(200));
INSERT @patterns(pat) VALUES
(N'I/O requests taking longer'),
(N'Error:'),
(N'failed'),
(N'Login failed'),
(N'autogrow'),
(N'corrupt'),
(N'stack dump'),
(N'assert');

DECLARE @i int = 1;
DECLARE @max int = (SELECT MAX(rn) FROM @patterns);

WHILE @i <= @max
BEGIN
    DECLARE @pat nvarchar(200) = (SELECT pat FROM @patterns WHERE rn = @i);

    PRINT '--- pattern: ' + @pat;

    EXEC master.dbo.xp_readerrorlog
        0,          -- log number (current)
        1,          -- log type (SQL Server)
        @pat,       -- search 1
        NULL,       -- search 2
        @start,     -- start date
        @end,       -- end date
        N'desc';    -- sort

    SET @i += 1;
END