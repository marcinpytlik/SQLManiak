-- 30-Logins-Export-A.sql
-- Uruchom na A. Generuje skrypty do przeniesienia loginów z zachowaniem SID i haseł.
-- Źródło: sp_help_revlogin (Microsoft KB).
IF OBJECT_ID('tempdb..#hlp') IS NOT NULL DROP TABLE #hlp;
-- skrócona wersja – w praktyce wklej pełny sp_help_revlogin z MS.
PRINT 'UWAGA: Wklej tutaj pełny skrypt sp_help_revlogin i wykonaj, a następnie uruchom sp_help_revlogin;';
