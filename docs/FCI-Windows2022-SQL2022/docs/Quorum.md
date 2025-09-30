# Quorum – zalecenia i przykłady

## Wybór modelu
- 2 węzły: **Node Majority + Witness**
  - **File Share Witness (FSW)** – prosty, on-prem.
  - **Cloud Witness** – Azure Storage Account (najmniej miejsca, prosty ruch).
- 3+ węzły: zwykle **Node Majority** (+/- Witness w zależności od rozproszenia).

## File Share Witness (FSW)
Wymagania:
- Udział SMB wysokiej dostępności (poza klastrem SQL).
- Uprawnienia CNO do udziału (Read/Write).

Komendy:
```powershell
Set-ClusterQuorum -FileShareWitness \\FS\ClusterWitness
Get-ClusterQuorum
```

## Cloud Witness (Azure)
Wymagania:
- Subskrypcja Azure, Storage Account, klucz dostępu.
- Łączność TCP/HTTPS do Azure.

Komendy – szablon:
```powershell
# Uwaga: wymaga modułu i poprawnych parametrów do Storage Account
Set-ClusterQuorum -CloudWitness `
  -AccountName "<storage-account-name>" `
  -AccessKey   "<access-key>" `
  -Endpoint    "core.windows.net"

Get-ClusterQuorum
```
