/* Quick errorlog scan (last 2 days) for important patterns.
   Requires xp_readerrorlog access (typically sysadmin).
*/
SET NOCOUNT ON;

DECLARE @days int = 2;

-- patterns
DECLARE @patterns TABLE (pat nvarchar(200));
INSERT @patterns(pat) VALUES
(N'I/O requests taking longer'),
(N'Error:'),
(N'failed'),
(N'Login failed'),
(N'autogrow'),
(N'corrupt'),
(N'stack dump'),
(N'assert');

DECLARE @i int = 0;
WHILE @i < (SELECT COUNT(*) FROM @patterns)
BEGIN
    DECLARE @pat nvarchar(200) = (SELECT pat FROM (SELECT pat, ROW_NUMBER() OVER (ORDER BY pat) rn FROM @patterns) x WHERE rn = @i+1);

    PRINT '--- pattern: ' + @pat;

    EXEC master.dbo.xp_readerrorlog 0, 1, @pat, NULL, DATEADD(DAY, -@days, SYSDATETIME()), SYSDATETIME(), N'desc';

    SET @i += 1;
END
