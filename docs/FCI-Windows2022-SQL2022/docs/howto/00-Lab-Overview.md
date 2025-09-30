# Lab — przegląd i topologia

**Domena:** `sqlmaniak.blog`  
**Adresy:** `DC=192.168.11.1`, `NODE1=192.168.11.2`, `NODE2=192.168.11.3`, `STORAGE=192.168.11.4`  
**VNN/VIP:** `SQLSRV-FCI` / `192.168.11.60`  
**Dyski FCI:** `Cluster Disk 1` (E:\Data), `Cluster Disk 2` (F:\Logs)  
**Konto usługi SQL:** gMSA `sqlmaniak\gmsa_sql$`

Składniki:
- **DC** (AD DS + DNS) — skrypt: `scripts/dc/installDomain.ps1`
- **STORAGE** (iSCSI Target) — skrypt: `scripts/storage/New-Iscsi-FciDisks.ps1`
- **NODE1/NODE2** (WSFC + SQL FCI) — skrypty: `scripts/cluster/New-WSFC.ps1`, `scripts/sql/*`, `scripts/guest/Connect-Iscsi-And-Init.ps1`

Diagramy: `docs/images/FCI-Cluster-Diagram.svg` (wersja 1 NIC), `...-HB.svg` (wariant z HB).
