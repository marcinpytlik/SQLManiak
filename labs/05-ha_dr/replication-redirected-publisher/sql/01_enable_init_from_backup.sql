/*
  Ustaw allow_initialize_from_backup = true na publikacji (uruchom na Server A).
*/
DECLARE @Publication sysname = N'PubName';

EXEC sp_changepublication
  @publication = @Publication,
  @property    = N'allow_initialize_from_backup',
  @value       = N'true';

EXEC sp_helppublication @publication = @Publication;
