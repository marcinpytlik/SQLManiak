-- 5) Zaległe komendy (szablon)
-- UZUPELNIJ parametry poniżej:
DECLARE 
  @publisher       sysname = @@SERVERNAME,
  @publisher_db    sysname = N'<PublisherDB>',
  @publication     sysname = N'<Publication>',
  @subscriber      sysname = N'<SubscriberServer>',
  @subscriber_db   sysname = N'<SubscriberDB>',
  @subscription_type int = 0; -- 0=Push, 1=Pull, 2=Anonymous

EXEC sp_replmonitorsubscriptionpendingcmds
  @publisher       = @publisher,
  @publisher_db    = @publisher_db,
  @publication     = @publication,
  @subscriber      = @subscriber,
  @subscriber_db   = @subscriber_db,
  @subscription_type = @subscription_type;
