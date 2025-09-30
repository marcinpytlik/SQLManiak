# FCI-Lab-HyperV — SQL Server 2022 FCI (WSFC)

Repo zawiera skrypty i przewodniki do zbudowania labu FCI:
- **docs/howto/** — krok‑po‑kroku (AD, iSCSI, WSFC, FCI, firewall, tempdb)
- **scripts/** — gotowe skrypty PowerShell/INI/SQL
- **docs/images/** — diagramy topologii

Szybki start:
1. `scripts/dc/installDomain.ps1` na DC (192.168.11.1)
2. `scripts/storage/New-Iscsi-FciDisks.ps1` na STORAGE (192.168.11.4)
3. `scripts/guest/Connect-Iscsi-And-Init.ps1` na NODE1/NODE2 (inicjalizacja tylko na NODE1)
4. `scripts/cluster/New-WSFC.ps1` na węźle
5. `scripts/sql/Install-FCI-FirstNode.ini` + `setup.exe` na NODE1
6. `scripts/sql/Install-FCI-AddNode.ini` + `setup.exe` na NODE2
7. `scripts/sql/Enable-Firewall-SQLFCI.ps1` na obu węzłach
8. `scripts/tests/Smoke-Test.ps1`

## Środowisko (checklista)

- [x] **4 serwery Windows Server 2022** — zaktualizowane na **wrzesień 2025**.
- [x] **DC (Core Edition)** — rola **AD DS + DNS** oraz **zasób klastra: File Share Witness (Quorum)** na dysku `C:`.
- [x] **NODE1 (GUI)** — członek domeny, węzeł WSFC, dwa dyski: `C:` (OS) oraz `T:` (lokalny **tempdb**).
- [x] **NODE2 (GUI)** — członek domeny, węzeł WSFC, dwa dyski: `C:` (OS) oraz `T:` (lokalny **tempdb**).
- [x] **STORAGE (GUI/Core)** — serwer usług dla klastra (iSCSI Target) dostarczający wspólne dyski **DATA/LOG** dla FCI.
- [x] **WSFC** utworzony (`SQLLAB`) z **FSW** na `\DC\Quorum$`.
- [x] **SQL Server 2022 FCI** (MSSQLSERVER) z VNN `SQLSRV-FCI` i VIP `192.168.11.60`.
- [x] Konto usługi **gMSA**: `sqlmaniak\gmsa_sql$` (SQL Engine), **SQL Agent**: `NT SERVICE\SQLSERVERAGENT`.

## Adresacja i role

| Host    | Rola                            | System / Edycja              | vCPU / RAM       | IP              | Dyski                         | Uwagi |
|--------:|---------------------------------|-------------------------------|:----------------:|-----------------|-------------------------------|-------|
| **DC** | AD DS, DNS, File Share Witness | Windows Server 2022 **Core** | 1 vCPU / 2 GB | `192.168.11.1` | `C:` | Udział `\\DC\\Quorum$` (quorum) |
| **NODE1** | Węzeł klastra (WSFC), SQL FCI | Windows Server 2022 **GUI** | 2 vCPU / 8 GB | `192.168.11.2` | `C:` (OS), `T:` (**tempdb**) | Lokalne `T:\\MSSQL` dla tempdb |
| **NODE2** | Węzeł klastra (WSFC), SQL FCI | Windows Server 2022 **GUI** | 2 vCPU / 8 GB | `192.168.11.3` | `C:` (OS), `T:` (**tempdb**) | Lokalne `T:\\MSSQL` dla tempdb |
| **STORAGE** | iSCSI Target (DATA/LOG) | Windows Server 2022 (GUI/Core) | 2 vCPU / 8 GB | `192.168.11.4` | `SQLData-iscsi.vhdx` (10 GB), `SQLLogs-iscsi.vhdx` (6 GB) | LUN-y: `SQLData-iscsi.vhdx` / `SQLLogs-iscsi.vhdx` |
| **SQLLAB** | Cluster Core Name (adres klastra) | — | — | `192.168.11.50` | — | IP klastra (Core Cluster Group) |
| **SQLSRV-FCI** | VNN (nazwa wirtualna) | — | — | `192.168.11.60` | — | VIP na `Cluster Network 1` |

> Notatka: `T:` jest lokalny na **NODE1/NODE2** (tylko tempdb), a współdzielone wolumeny danych/logów dostarcza iSCSI z **STORAGE** i są prezentowane w klastrze jako **Physical Disk** (np. `Cluster Disk 1/2`).
