# Runbook: Windows Server 2022 Failover Cluster Instance (FCI) + SQL Server 2022

Dokument: **instalacja, konfiguracja, utrzymanie i monitoring** FCI dla SQL Server 2022 na Windows Server 2022.  
Styl: zwięzła checklista + gotowe skrypty PowerShell.  
Adresat: administrator Windows/AD/SQL.

---

## 1) Założenia i topologia
- 2+ węzły Windows Server 2022 (Core/GUI), ta sama domena AD.
- Nazwa klastra (CNO): `SQLSRVCluster`.
- Nazwa instancji FCI (VNN): np. `SQLSRV-FCI` (default) lub `SQLSRV-FCI\INST1` (named).
- Storage współdzielony: LUN-y/dyski dla **Data**, **Log**, opcjonalnie **Backups**; `tempdb` **lokalnie** na SSD/NVMe (identyczne ścieżki).
- Sieci: co najmniej 2 (Public/Client, Private/Heartbeat).
- Quorum: **File Share Witness** lub **Cloud Witness** (Azure).

> Uwaga: `tempdb` lokalnie wymaga **identycznych ścieżek** na wszystkich węzłach. Brak katalogu zablokuje start instancji po failoverze.

---

## 2) Konta i uprawnienia
- Konto usług SQL/Agent: **gMSA** (zalecane) lub dedykowane konto domenowe.
- CNO (Computer Object klastra) ma prawo tworzyć VCO (VNN).
- Konta usług SQL mają prawa NTFS do lokalnych katalogów (`tempdb`) i do folderów na współdzielonych wolumenach.
- Jeśli iSCSI – konta/initiatory iSCSI przygotowane na każdym węźle.

---

## 3) Przygotowanie Windows Failover Clustering
1. Rola i narzędzia:
   ```powershell
   Install-WindowsFeature Failover-Clustering -IncludeManagementTools -Restart
   ```
2. Walidacja:
   ```powershell
   Test-Cluster -Node NODE1,NODE2 -Include "Storage","Inventory","Network","SystemConfiguration" -Verbose | Out-File C:\ClusterValidation.txt
   ```
3. Utworzenie klastra:
   ```powershell
   New-Cluster -Name SQLSRVCluster -Node NODE1,NODE2 -StaticAddress 10.0.0.50 -NoStorage
   ```
4. Quorum (przykład File Share Witness):
   ```powershell
   Set-ClusterQuorum -FileShareWitness \\FS\ClusterWitness
   ```

---

## 4) Sieci i ustawienia heartbeat
- W **Failover Cluster Manager → Networks**: nazwy i priorytety sieci (Public dla klienta, Private dla heartbeat).
- Zalecane zwiększenie progów dla heartbeat (redukcja niepotrzebnych failoverów):
  ```powershell
  (Get-Cluster).SameSubnetDelay     = 1000    # ms
  (Get-Cluster).SameSubnetThreshold = 10      # prob
  (Get-Cluster).CrossSubnetDelay     = 2000   # ms
  (Get-Cluster).CrossSubnetThreshold = 10
  ```

---

## 5) Storage i layout
- Oddziel **Data** i **Log** (różne LUN-y). Backups na osobnym wolumenie lub zewnętrznie.
- `tempdb` **lokalnie**: np. `T:\SQL\TempDB\` – identyczna litera/ścieżka na wszystkich węzłach.
- Wyrównaj rozmiary plików `tempdb` i ustaw autogrow w MB (np. 256–1024 MB).

Przygotowanie katalogów lokalnych (wszystkie węzły):
```powershell
$path = 'T:\SQL\TempDB'
New-Item -ItemType Directory -Path $path -Force | Out-Null
$svc = 'DOMAIN\gmsa_sql$'
icacls $path /grant "$svc:(OI)(CI)F" /T
```

---

## 6) Instalacja SQL Server 2022 jako FCI
**Pierwszy węzeł:**
- *New SQL Server failover cluster installation* (VNN, IP, Data/Log na współdzielonych wolumenach).
- `tempdb` wskaż na **lokalny** dysk (np. `T:\SQL\TempDB\`).

**Drugi węzeł (i kolejne):**
- *Add node to a SQL Server failover cluster*. Upewnij się, że ścieżki `tempdb` istnieją.

**Po instalacji:**
- Ręczny failover w FCM i weryfikacja logów ERRORLOG/Agent, łączności do VNN.

---

## 7) Preferred Owners i Anti‑Affinity
- Ustaw **Preferred Owners**, aby rola SQL wracała na preferowany węzeł po restartach.
- Dla wielu instancji – **Anti‑Affinity**, żeby nie wylądowały razem na jednym węźle.

---

## 8) Cluster‑Aware Updating (CAU)
- Patchowanie Windows sekwencyjnie (**Drain → Update → Reboot → Resume**).
- Pre/Post skrypty do smoke‑testów SQL.

---

## 9) Monitoring i alerty
- Dzienniki: *FailoverClustering/Operational*, eventy 1135/1205 itd.
- Mierniki: dostępność roli, czas failoveru, ERRORLOG SQL, pojemność dysków.

---

## 10) Runbook testu failoveru (kwartalnie)
1. `Suspend-ClusterNode -Drain` na aktywnym węźle, sprawdź przejście roli.
2. Test połączeń do VNN, zapytania, joby, backupy.
3. `Resume-ClusterNode` i przerzuć z powrotem na preferowany.
4. Zarchiwizuj wyniki.

---

## 11) Troubleshooting
- SQL nie startuje na drugim węźle → ścieżka/ACL `tempdb`?
- Flapping → progi heartbeat, sieci, storage.
- VNN/DNS → uprawnienia CNO/VCO, duplikaty.

---

## 12) Załączone skrypty (skrót)
- `Set-ClusterTimeouts.ps1`, `Configure-Quorum.ps1`, `Validate-Cluster.ps1`  
- `Prepare-TempDB-Folders.ps1`, `Set-PreferredOwners.ps1`, `AntiAffinityRules.ps1`
- `Patch-SqlFci-Rolling.ps1` (CU), `Patch-Windows-ClusterNodes.ps1` (KB), `CAU-Register.ps1`
- `PreCheck-SqlSmoke.ps1`, `PostCheck-SqlSmoke.ps1`, `config/_Env.sample.ps1`
- ADR: `ADR-Audit.sql`, `ADR-Enable.sql`, `ADR-Enable-Bulk.ps1`

---

## 15) Patchowanie SQL FCI – rolling upgrade (skrypt)
Patrz `scripts/Patch-SqlFci-Rolling.ps1` – `/ACTION=Patch`, Drain/Resume, logowanie.

---

## 16) Patchowanie Windows (KB) – rolling z PSWindowsUpdate
Patrz `scripts/Patch-Windows-ClusterNodes.ps1` oraz `scripts/CAU-Register.ps1`.

---

## 17) Pre/Post check – „smoke test” dla SQL
Patrz `scripts/PreCheck-SqlSmoke.ps1` i `scripts/PostCheck-SqlSmoke.ps1` + `config/_Env.sample.ps1`.

---

## 18) ADR – audyt i masowe włączenie
Patrz `scripts/ADR-Audit.sql`, `scripts/ADR-Enable.sql`, `scripts/ADR-Enable-Bulk.ps1`.

---

## 19) Źródła (oficjalne materiały Microsoft)

### Windows Server Failover Clustering (WSFC)
- Przegląd WSFC: https://learn.microsoft.com/en-us/windows-server/failover-clustering/failover-clustering-overview
- Walidacja – Test-Cluster: https://learn.microsoft.com/en-us/powershell/module/failoverclusters/test-cluster
- Moduł FailoverClusters – cmdlety: https://learn.microsoft.com/en-us/powershell/module/failoverclusters/
- New-Cluster: https://learn.microsoft.com/en-us/powershell/module/failoverclusters/new-cluster
- Tuning progów heartbeat: https://learn.microsoft.com/en-us/troubleshoot/windows-server/high-availability/iaas-sql-failover-cluster-network-thresholds
- File Share Witness: https://learn.microsoft.com/en-us/windows-server/failover-clustering/file-share-witness
- Quorum – konfiguracja świadka: https://learn.microsoft.com/en-us/windows-server/failover-clustering/deploy-quorum-witness

### SQL Server FCI
- WSFC z SQL Server – przegląd: https://learn.microsoft.com/en-us/sql/sql-server/failover-clusters/windows/windows-server-failover-clustering-wsfc-with-sql-server
- Instalacja FCI (Setup): https://learn.microsoft.com/en-us/sql/sql-server/failover-clusters/install/sql-server-failover-cluster-installation
- Before Installing Failover Clustering (m.in. tempdb na lokalnym dysku): https://learn.microsoft.com/en-us/sql/sql-server/failover-clusters/install/before-installing-failover-clustering

### Setup/aktualizacje SQL
- Instalacja z wiersza poleceń – parametry setup.exe: https://learn.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt
- Instalowanie aktualizacji z wiersza poleceń (`/ACTION=Patch`): https://learn.microsoft.com/en-us/sql/database-engine/install-windows/installing-updates-from-the-command-prompt
- Server Core – aktualizacje po instalacji: https://learn.microsoft.com/en-us/sql/database-engine/install-windows/configure-sql-server-on-a-server-core-installation

### Cluster‑Aware Updating (CAU)
- Przegląd: https://learn.microsoft.com/en-us/windows-server/failover-clustering/cluster-aware-updating
- Wymagania: https://learn.microsoft.com/en-us/windows-server/failover-clustering/cluster-aware-updating-requirements
- Add-CauClusterRole (cmdlet): https://learn.microsoft.com/en-us/powershell/module/clusterawareupdating/add-cauclusterrole

### Accelerated Database Recovery (ADR)
- Koncepcje: https://learn.microsoft.com/en-us/sql/relational-databases/accelerated-database-recovery-concepts
- Zarządzanie/włączanie + PVS FG: https://learn.microsoft.com/en-us/sql/relational-databases/accelerated-database-recovery-management
- Monitorowanie/diagnoza: https://learn.microsoft.com/en-us/sql/relational-databases/accelerated-database-recovery-troubleshoot
- DMV PVS: https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-persistent-version-store-stats
