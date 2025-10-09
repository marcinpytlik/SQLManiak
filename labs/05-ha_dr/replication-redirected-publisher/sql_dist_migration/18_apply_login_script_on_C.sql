/*
  Ten plik to przypominajka: skopiuj wynik z 17_generate_login_script_from_A.sql
  i uruchom na **Server C**. Następnie zweryfikuj loginy i role:
*/

SELECT name, sid, type_desc, is_disabled
FROM sys.server_principals
WHERE name IN (N'repl_distribution', N'repl_logreader', N'repl_snapshot')
ORDER BY name;

-- Test logowania agentów i ponowne uruchomienie jobów dystrybucji po stronie C.
