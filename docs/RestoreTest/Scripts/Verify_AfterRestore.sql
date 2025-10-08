-- Weryfikacja po RESTORE
DBCC CHECKDB([DemoDB_Test]) WITH NO_INFOMSGS;
SELECT name, state_desc, recovery_model_desc 
FROM sys.databases WHERE name = 'DemoDB_Test';
