
# FCI gMSA Setup Pack (SQL Server 2022 + Windows Server 2022)

Minimalny, produkcyjny przepływ do postawienia **nowej instancji SQL Server 2022 FCI** na **Windows Server 2022** z kontem **gMSA**.
Repo zawiera gotowe skrypty PowerShell/SQL + checklistę weryfikacji i proste taski VS Code.

## Założenia (możesz zmienić w `param()` skryptów)
- Domena: `sqlmaniak.lab`
- Węzły klastra: `NODE1`, `NODE2` (dodaj własne)
- Klaster (Windows Failover Cluster): `SQLCLUSTER`
- VNN (nazwa sieciowa FCI): `SQLPROD`
- Port: `1433`
- Konto gMSA (bez `$` w param): `sqlsvc_fci01`

> Wszystkie skrypty mają sekcję `param(...)` – **uruchamiaj z własnymi wartościami** lub edytuj domyślne.

---

## Szybki start

1. **Na DC lub serwerze admin (z modułem AD):**
   ```powershell
   .\scripts\New-gMSA.ps1 -Domain 'sqlmaniak.lab' -GmsaName 'sqlsvc_fci01' -Hosts 'NODE1','NODE2' -HostsGroup 'GRP_SQL_FCI01_GMSA_Hosts' -OuPath 'OU=SQL,DC=sqlmaniak,DC=lab'
   ```

2. **Na KAŻDYM węźle klastra:**
   ```powershell
   .\scripts\Install-gMSA-OnNodes.ps1 -GmsaName 'sqlsvc_fci01'
   ```

3. **Zainstaluj SQL Server 2022 FCI** i na ekranie *Server Configuration* wpisz:
   - Engine: `sqlmaniak\sqlsvc_fci01$` (hasło puste)
   - (opcjonalnie) Agent: `sqlmaniak\sqlsvc_fci01$`

4. **Po instalacji – SPN dla VNN:**
   ```powershell
   .\scripts\Register-SPN.ps1 -Domain 'sqlmaniak.lab' -GmsaName 'sqlsvc_fci01' -VnnFqdn 'SQLPROD.sqlmaniak.lab' -Port 1433
   ```

5. **Weryfikacja Kerberosa (z SSMS lub sqlcmd):**
   ```sql
   :r .\scripts\Test-Kerberos.sql
   ```

---

## Zawartość

- `scripts/New-gMSA.ps1` – KDS (jeśli brak), grupa hostów, gMSA.
- `scripts/Install-gMSA-OnNodes.ps1` – RSAT-AD-PowerShell + instalacja gMSA i test.
- `scripts/Register-SPN.ps1` – rejestracja SPN dla VNN (i opcjonalnie Listener).
- `scripts/Test-Kerberos.sql` – szybki test `auth_scheme` = KERBEROS.
- `docs/Checklist.md` – kontrolna lista kroków.
- `docs/Troubleshooting.md` – typowe problemy i szybkie fixy.
- `.vscode/tasks.json` – taski do odpalenia skryptów PS i SQL z VS Code.

---

## Minimalne wymagania

- **SQL Server 2022** (Failover Cluster Instance)
- **Windows Server 2022**
- Uprawnienia do tworzenia kont serwisowych, grup, SPN w AD
- Moduł AD: `Install-WindowsFeature RSAT-AD-PowerShell` (na hostach, które uruchamiają cmdlety AD)

---

## Bezpieczeństwo i praktyki

- gMSA rotuje hasło automatycznie (domyślnie ~30 dni).
- Uprawnienia NTFS/SMB: daj tylko to, czego potrzeba (DATA/LOG/BACKUP).
- Porty: dla Kerberosa przy nazwanych instancjach ustaw port statyczny i dodaj SPN z portem.
- Nie dodawaj gMSA do Local Admins – Configuration Manager i tak nada niezbędne prawa usługom SQL.

---

## Weryfikacja końcowa

1. `SELECT auth_scheme FROM sys.dm_exec_connections WHERE session_id = @@SPID;` → **KERBEROS**
2. Failover w **Failover Cluster Manager** → usługa wstaje na drugim węźle bez błędów.
3. Test dostępu do dysków danych/backupów.
4. Test logowania z klienta zewnętrznego (Kerberos, SPN działa).

---

Autor: **Marcin Pytlik | SQLManiak**  
Licencja: **CC BY 4.0**
