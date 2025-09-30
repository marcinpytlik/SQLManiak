# SQL Server 2022 FCI — dołączanie drugiego węzła (**AddNode**)

Ten mini‑przewodnik pokazuje **jak poprawnie dołączyć NODE2** do już istniejącej instancji **SQL Server 2022 FCI** na Windows Server Failover Cluster (WSFC). Struktura i przykłady są dopasowane do labu:
- Domena: `sqlmaniak.blog`
- Adresacja: `DC=192.168.11.1`, `NODE1=192.168.11.2`, `NODE2=192.168.11.3`, `STORAGE=192.168.11.4`
- VNN: `SQLSRV-FCI`, VIP: `192.168.11.60`
- Dyski FCI: *Cluster Disk 1* (E:\Data) i *Cluster Disk 2* (F:\Logs)
- Konto usługi SQL: **gMSA** `sqlmaniak\gmsa_sql$`

> Uwaga: plik poniżej dotyczy **AddNode** (drugi i kolejne węzły). Pierwszy węzeł instalujesz trybem `InstallFailoverCluster`.

---

## 1) Wymagania wstępne

1. **WSFC działa** i grupa FCI istnieje (z VNN i VIP).  
2. Dyski danych/logów są **zasobami „Physical Disk”** w grupie instancji, a nie w „Available Storage”.  
3. **NODE2** ma takie same **lokalne ścieżki** (np. dla tempdb, jeśli użyłeś lokalnego T:\):  
   ```powershell
   New-Item -ItemType Directory -Path 'T:\MSSQL' -Force | Out-Null
   ```
4. **gMSA** zainstalowane na węzłach:  
   ```powershell
   Install-ADServiceAccount gmsa_sql
   Test-ADServiceAccount gmsa_sql
   ```
5. (Jeśli wcześniej były problemy z VNN/AD) — upewnij się, że **CNO** klastra (`SQLLAB$`) może tworzyć/zarządzać obiektem komputera **`SQLSRV-FCI`** (lub pre‑utwórz go jako *Disabled* i nadaj **Full Control** dla CNO).

---

## 2) Minimalny plik konfiguracyjny **AddNode** (INI)

Zapisz jako np. `C:\Temp\SQL_FCI_AddNode.ini`:

```ini
; SQL Server 2022 AddNode Configuration
[OPTIONS]
ACTION="AddNode"
ENU="True"
QUIET="False"
UIMODE="Normal"
UpdateEnabled="True"

; ta sama instancja co na pierwszym węźle
INSTANCENAME="MSSQLSERVER"

; konta usług (identycznie jak na pierwszym węźle)
SQLSVCACCOUNT="sqlmaniak\gmsa_sql$"
AGTSVCACCOUNT="NT SERVICE\SQLSERVERAGENT"
FTSVCACCOUNT="NT Service\MSSQLFDLauncher"

; dobre praktyki
SQLSVCINSTANTFILEINIT="True"

; akceptacja licencji
IACCEPTSQLSERVERLICENSETERMS="True"
```

> Świadomie **nie** podajemy tu `FAILOVERCLUSTERIPADDRESSES`, `FAILOVERCLUSTERNETWORKNAME` ani `FAILOVERCLUSTERGROUP` — AddNode dziedziczy to z istniejącej instancji FCI i tak jest najbezpieczniej.

---

## 3) Uruchomienie instalatora na NODE2

W trybie z plikiem INI:
```powershell
D:\setup.exe /ConfigurationFile="C:\Temp\SQL_FCI_AddNode.ini"
```

Albo z UI (wygodnie gdy chcesz potwierdzić ścieżki):  
```powershell
D:\setup.exe /Action=AddNode /InstanceName=MSSQLSERVER
```

---

## 4) Kontrolna lista przed startem

```powershell
# Klaster żyje i widzi oba węzły?
Get-Cluster | fl Name,State
Get-ClusterGroup | ft Name,OwnerNode,State

# Dyski FCI są w grupie instancji, nie w "Available Storage"
Get-ClusterResource -ResourceType "Physical Disk" | ft Name,OwnerGroup,State

# (Opcjonalnie) jeśli używasz lokalnego tempdb – ścieżka istnieje na NODE2
Test-Path 'T:\MSSQL'
```

---

## 5) Po udanym AddNode — smoke test

```powershell
# Failover na NODE2
Move-ClusterGroup "SQL Server (MSSQLSERVER)" -Node NODE2

# Szybki test połączenia
sqlcmd -S SQLSRV-FCI -Q "SELECT @@SERVERNAME AS NodeName, SYSDATETIME() AS Now;"
```

**Kerberos/SPN** (tylko jeśli setup nie ustawił automatycznie):  
```powershell
setspn -S MSSQLSvc/SQLSRV-FCI:1433 sqlmaniak\gmsa_sql$
setspn -S MSSQLSvc/SQLSRV-FCI.sqlmaniak.blog:1433 sqlmaniak\gmsa_sql$
```

---

## 6) Najczęstsze potknięcia i szybkie poprawki

- **Brak lokalnej ścieżki tempdb** na NODE2 → załóż folder (np. `T:\MSSQL`) albo na czas AddNode usuń `SQLTEMPDBDIR` z instalacji i przenieś tempdb po fakcie.  
- **Agent na gMSA** → używaj `AGTSVCACCOUNT="NT SERVICE\SQLSERVERAGENT"` (sprawdzone i bezbolesne).  
- **Zła nazwa sieci w parametrach IP** → AddNode nie potrzebuje parametrów IP; jeśli instalujesz pierwszy węzeł, nazwę sprawdzaj `Get-ClusterNetwork`.  
- **Brak uprawnień CNO do VNN** → precreate VNN (Disabled) i nadaj CNO **Full Control** w AD.  
- **Dyski nie w grupie instancji** → upewnij się, że są zasobami „Physical Disk” w grupie `SQL Server (MSSQLSERVER)`.

**Logi instalatora** (gdyby coś poszło nie tak):  
```powershell
$root = "C:\Program Files\Microsoft SQL Serverp\Setup Bootstrap\Log"
$last = Get-ChildItem $root -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content "$($last.FullName)\Summary.txt" -Tail 150
```

---

## 7) Co dalej?

- Przenieś `tempdb` na lokalny T:\ (jeśli jeszcze nie): `ALTER DATABASE tempdb ...` i zrestartuj rolę SQL.  
- Włącz/zweryfikuj **TLS, IFI, LPIM**, audyt i backupy logów (dla FULL).  
- Zrób **test failoveru w obie strony** i zmierz czas odzyskiwania (ADR skraca recovery).

Miłej jazdy — teraz NODE2 powinien wejść do FCI bez foszków. 🚀
