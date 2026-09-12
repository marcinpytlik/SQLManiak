# Stage 3 - konto techniczne, udział, Credential i Proxy

Kolejność:

1. `07-create-export-account.ps1` - tworzy `SQLLAB\poc-ssis-export` w `OU=POC` i utrzymuje wyłączoną delegację.
2. `08-create-test-share.ps1` - uruchom jako administrator na serwerze plików; tworzy katalog i udział `SSISLab$`, nadając kontu technicznemu `Change` na share i `Modify` w NTFS.
3. `09-test-share-access.ps1 -SharePath '\\FILESERVER\SSISLab$'` - sprawdza zapis i usunięcie pliku jako `SQLLAB\poc-ssis-export`.
4. `10-create-sql-agent-credential.ps1 -SqlInstance 'SQLSERVER'` - tworzy/aktualizuje `POC_SSIS_Export_Credential`; hasło jest podawane interaktywnie i nie trafia do repo.
5. `11-create-ssis-proxy.sql` - tworzy `POC_SSIS_Export_Proxy` i przyznaje mu wyłącznie subsystem `SSIS`.
6. `12-verify-stage3.sql` - weryfikuje Credential, Proxy i subsystem; `Stage3SqlAgentConfigurationOK` powinno zwrócić `1`.

Nie przechodź do Stage 4, dopóki test zapisu na share nie przejdzie poprawnie.

Założenia bezpieczeństwa:

- `SQLLAB\poc-ssis-app` nie otrzymuje praw do SQL Agenta, Credential, Proxy, SSISDB ani udziału.
- `SQLLAB\poc-ssis-export` jest osobnym kontem technicznym.
- oba konta mają wyłączoną delegację.
- Proxy ma dostęp tylko do subsystemu `SSIS`.
- hasła nie są przechowywane w repozytorium.
