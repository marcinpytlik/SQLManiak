
# FCI gMSA Setup  (SQL Server 2022 + Windows Server 2022)

Nowa instancja **SQL Server 2022 FCI** na **Windows Server 2022** z **oddzielnymi gMSA**:
- `sqlsvc_fci01$` — dla **Database Engine**
- `sqlagt_fci01$` — dla **SQL Server Agent**

Dodatkowo: **pipeline GitHub Actions** do automatycznej rejestracji **SPN** po deployu.

## Szybki start

### 1) AD/DC – utwórz oba konta gMSA i grupę hostów
```powershell
./scripts/New-gMSA-Pair.ps1 -Domain 'sqlmaniak.lab' `
  -EngineGmsa 'sqlsvc_fci01' -AgentGmsa 'sqlagt_fci01' `
  -Hosts 'NODE1','NODE2' -HostsGroup 'GRP_SQL_FCI01_GMSA_Hosts' `
  -OuPath 'OU=SQL,DC=sqlmaniak,DC=lab'
```

### 2) Każdy węzeł — zainstaluj oba gMSA
```powershell
./scripts/Install-gMSA-Pair-OnNodes.ps1 -EngineGmsa 'sqlsvc_fci01' -AgentGmsa 'sqlagt_fci01'
```

### 3) Instalacja SQL FCI
Na ekranie *Server Configuration*:
- **Engine**: `sqlmaniak\sqlsvc_fci01$` (hasło puste)
- **Agent**: `sqlmaniak\sqlagt_fci01$` (hasło puste)

### 4) SPN dla VNN (silnik SQL)
```powershell
./scripts/Register-SPN.ps1 -Domain 'sqlmaniak.lab' -GmsaName 'sqlsvc_fci01' -VnnFqdn 'SQLPROD.sqlmaniak.lab' -Port 1433
```

> Uwaga: **Agent nie potrzebuje SPN**. SPN rejestrujemy dla konta gMSA silnika SQL (MSSQLSvc).

### 5) Weryfikacja Kerberosa
```sql
:r ./scripts/Test-Kerberos.sql
```

---

## Automatyzacja rejestracji SPN — GitHub Actions

W repo znajdziesz: `.github/workflows/register-spn.yml`

- **Wymaga self‑hosted Windows runnera** dołączonego do domeny (konto usługi runnera musi mieć delegację do zapisu SPN *na koncie gMSA silnika* albo być Domain Adminem).
- Uruchamiasz z **workflow_dispatch** z parametrami (`domain`, `gmsa`, `vnn_fqdn`, `port`).

Szczegóły konfiguracji: `docs/Delegation_and_Runner.md`.

---

## Zawartość
- `scripts/New-gMSA-Pair.ps1` – oba gMSA + grupa hostów + KDS jeśli brak.
- `scripts/Install-gMSA-Pair-OnNodes.ps1` – instalacja obu gMSA na węźle.
- `scripts/Register-SPN.ps1` – SPN dla VNN/Listener przypisany do **gMSA silnika**.
- `scripts/Test-Kerberos.sql` – weryfikacja Kerberos.
- `.github/workflows/register-spn.yml` – pipeline.
- `docs/Checklist.md` – lista kontrolna wdrożenia.
- `docs/Troubleshooting.md` – szybkie naprawy.
- `docs/Delegation_and_Runner.md` – uprawnienia i runner domenowy.
- `.vscode/tasks.json` – taski VS Code.

---

Autor: **Marcin Pytlik | SQLManiak**  
Licencja: **CC BY 4.0**
