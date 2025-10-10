-- 31-Logins-Import-B.sql
-- Uruchom wygenerowany skrypt z A na B.
-- Uwaga na mapowanie użytkowników (orphaned users):
EXEC sp_change_users_login 'Report';
-- Dla każdej bazy:
-- ALTER USER [domain\svc_aos] WITH LOGIN=[domain\svc_aos];
