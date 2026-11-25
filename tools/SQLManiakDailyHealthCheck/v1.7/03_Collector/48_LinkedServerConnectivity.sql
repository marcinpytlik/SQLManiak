-- Template: the PowerShell collector supplies @ProbeName via a safely escaped Unicode literal.
-- Do not run manually without declaring @ProbeName.
SET NOCOUNT ON;
DECLARE @Started datetime2(3)=SYSUTCDATETIME(), @Sql nvarchar(max),
 @Connect int,@Query int,@Status varchar(40)='SKIPPED',@Details nvarchar(2048)=NULL,
 @ErrorNumber int=NULL,@ErrorSeverity int=NULL,@ErrorState int=NULL;
CREATE TABLE #Remote(RemoteServer nvarchar(128),RemoteLogin nvarchar(128),AuthScheme nvarchar(40));
SELECT @Connect=CASE WHEN connect_timeout=0 THEN (SELECT CONVERT(int,value_in_use) FROM sys.configurations WHERE name='remote login timeout (s)') ELSE connect_timeout END,
 @Query=CASE WHEN query_timeout=0 THEN (SELECT CONVERT(int,value_in_use) FROM sys.configurations WHERE name='remote query timeout (s)') ELSE query_timeout END
FROM sys.servers WHERE is_linked=1 AND is_data_access_enabled=1 AND name=@ProbeName;
IF @Connect BETWEEN 1 AND 15 AND @Query BETWEEN 1 AND 30 AND @@TRANCOUNT=0
BEGIN
 BEGIN TRY
  SET @Sql=N'SELECT RemoteServer,RemoteLogin,AuthScheme FROM OPENQUERY('+QUOTENAME(@ProbeName)+
    N', ''SELECT CONVERT(nvarchar(128),@@SERVERNAME) AS RemoteServer, CONVERT(nvarchar(128),ORIGINAL_LOGIN()) AS RemoteLogin, CONVERT(nvarchar(40),CONNECTIONPROPERTY(''''auth_scheme'''')) AS AuthScheme'')';
  -- No explicit transaction: avoid INSERT EXEC remote query transaction promotion.
  -- Return remote identity via output parameters in the dynamic batch.
  DECLARE @RemoteServer nvarchar(128),@RemoteLogin nvarchar(128),@AuthScheme nvarchar(40);
  SET @Sql=N'SELECT @s=RemoteServer,@l=RemoteLogin,@a=AuthScheme FROM ('+@Sql+N') q';
  EXEC sys.sp_executesql @Sql,N'@s nvarchar(128) OUTPUT,@l nvarchar(128) OUTPUT,@a nvarchar(40) OUTPUT',@s=@RemoteServer OUTPUT,@l=@RemoteLogin OUTPUT,@a=@AuthScheme OUTPUT;
  IF @RemoteServer IS NULL THROW 51000,'Remote identity not returned.',1;
  INSERT #Remote VALUES(@RemoteServer,@RemoteLogin,@AuthScheme);
  SET @Status='PASS';
 END TRY
 BEGIN CATCH
  SELECT @Status='FAILED',@Details=ERROR_MESSAGE(),@ErrorNumber=ERROR_NUMBER(),@ErrorSeverity=ERROR_SEVERITY(),@ErrorState=ERROR_STATE();
 END CATCH
END
ELSE SET @Details=N'Missing/disabled server, ambient transaction or effective timeout outside 1-15/1-30 seconds.';
SELECT 'LINKED_SERVER_CONNECTIVITY' AS Section,@ProbeName AS LinkedServer,@Status AS ProbeStatus,
 DATEDIFF_BIG(millisecond,@Started,SYSUTCDATETIME()) AS DurationMs,ORIGINAL_LOGIN() AS CollectorLogin,
 CONNECTIONPROPERTY('auth_scheme') AS LocalAuthScheme,
 r.RemoteServer,r.RemoteLogin,r.AuthScheme AS RemoteAuthScheme,
 @ErrorNumber AS ErrorNumber,@ErrorSeverity AS ErrorSeverity,@ErrorState AS ErrorState,@Details AS Details
FROM (VALUES(1)) v(n) LEFT JOIN #Remote r ON 1=1;
