# SQL Server — naprawa wewnętrznej nazwy serwera (`@@SERVERNAME`) po zmianie nazwy hosta

Pakiet „wrzuć i użyj” dla **pustych** instancji SQL Server (2016–2022). Skrypty aktualizują wpis w `sys.servers` tak,
aby `@@SERVERNAME` zgadzał się z `SERVERPROPERTY('ServerName')` po renamie/ponownym dołączeniu do domeny.

## Zawartość
- `scripts/01_Fix_ServerName.sql` — idempotentny skrypt: porównuje nazwę, `sp_dropserver` → `sp_addserver '...','local'` w razie rozbieżności.
- `scripts/02_Verify.sql` — szybka walidacja po restarcie.
- `scripts/Restart-SqlService.ps1` — restart usług (domyślna lub nazwana instancja).
- `.vscode/tasks.json` — 2 zadania pod VS Code: **Fix** i **Verify** (sqlcmd).

## Szybki start (3 kroki)
1. Otwórz folder w VS Code.
2. Uruchom task **SQL: Fix ServerName** (Ctrl/Cmd+Shift+P → „Run Task”).  
   - Alternatywnie: odpal `scripts/01_Fix_ServerName.sql` ręcznie.
3. Zrestartuj usługę (skrypt PowerShell) i uruchom task **SQL: Verify** lub `scripts/02_Verify.sql`.

## Uwaga
- **Nie używaj FQDN** (np. `serwer.domena.com`) w `sp_addserver`. Prawidłowy format to `HOST` lub `HOST\INSTANCJA`.
- Dla klastrów FCI/AG ta procedura dotyczy tylko lokalnej nazwy instancji, *nie* zasobu klastra (tam rządzi Cluster Name).

---
