/*
  Walidacja na C: metadane publikacji oraz walidacja przekierowania.
*/
DECLARE @Publication sysname = N'PubName';
DECLARE @OriginalPublisher sysname  = N'ServerA';
DECLARE @PublisherDb sysname        = N'TwojaBaza';

-- Publikacja
EXEC sp_helppublication @publication = @Publication;

-- Walidacja redirected publisher
EXEC sp_validate_redirected_publisher
  @publisher    = @OriginalPublisher,
  @publisher_db = @PublisherDb;
