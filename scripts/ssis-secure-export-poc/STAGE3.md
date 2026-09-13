# Stage 3 - konto techniczne, udział, Credential i Proxy

Cały etap administrujemy z `DEWELOPER`.

PowerShell uruchamiamy lokalnie przez `pwsh`, a skrypty SQL z Visual Studio Code połączonego do `sql64.sqllab.local,1433` przez Windows Authentication.

Kolejność:

1. `07-create-export-account.ps1` - uruchom na `DEWELOPER`; przez WinRM do `DC01` tworzy `SQLLAB\poc-ssis-export` w `OU=POC` i utrzymuje wyłączoną delegację.
2. `08-create-test-share.ps1` - uruchom na `DEWELOPER`; przez WinRM do `DC01` tworzy katalog i udział `SSISLab$`, nadając kontu technicznemu `Change` na share i `Modify` w NTFS.
3. `09-test-share-access.ps1` - uruchom na `DEWELOPER`; sprawdza rzeczywisty create/read/delete na `\\dc01.sqllab.local\SSISLab$` jako `SQLLAB\poc-ssis-export`.
4. `10-create-sql-agent-credential.ps1` - uruchom na `DEWELOPER`; łączy się do `sql64.sqllab.local,1433` i tworzy/aktualizuje `POC_SSIS_Export_Credential`. Hasło jest podawane interaktywnie i nie trafia do repo.
5. `11-create-ssis-proxy.sql` - uruchom z VS Code na `SQL64`; tworzy `POC_SSIS_Export_Proxy` i przyznaje mu wyłącznie subsystem `SSIS`.
6. `12-verify-stage3.sql` - uruchom z VS Code na `SQL64`; weryfikuje Credential, Proxy i subsystem.

Nie przechodź do Stage 4, dopóki test zapisu na share nie przejdzie poprawnie.

Założenia bezpieczeństwa:

- `SQLLAB\poc-ssis-app` nie otrzymuje praw do SQL Agenta, Credential, Proxy, SSISDB ani udziału,
- `SQLLAB\poc-ssis-export` jest osobnym kontem technicznym,
- oba konta mają wyłączoną delegację,
- Proxy ma dostęp tylko do subsystemu `SSIS`,
- hasła nie są przechowywane w repozytorium,
- nie używamy połączenia `DEWELOPER -> SQL64 -> DC01`; operacje do SQL64 i DC01 są wykonywane jako dwa niezależne połączenia.
