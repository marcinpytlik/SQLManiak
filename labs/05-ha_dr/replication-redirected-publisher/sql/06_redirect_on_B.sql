/*
  Na subskrybencie B: przekierowanie wydawcy A → C dla danej bazy.
*/
DECLARE @OriginalPublisher sysname = N'ServerA';
DECLARE @PublisherDb sysname       = N'TwojaBaza';
DECLARE @RedirectedPublisher sysname = N'ServerC';

EXEC sp_redirect_publisher
  @original_publisher    = @OriginalPublisher,
  @publisher_db          = @PublisherDb,
  @redirected_publisher  = @RedirectedPublisher;

-- Podgląd mapowania
EXEC sp_get_redirected_publisher
  @publisher     = @OriginalPublisher,
  @publisher_db  = @PublisherDb;
