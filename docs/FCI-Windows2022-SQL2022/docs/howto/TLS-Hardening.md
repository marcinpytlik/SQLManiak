# TLS Hardening dla SQL Server 2022 (Windows Server 2019/2022)

Cel: **wymusić TLS 1.2**, wyłączyć TLS 1.0/1.1, ustawić certyfikat i – opcjonalnie – wymusić szyfrowanie na instancji.

> Uwaga: SQL Server 2022 używa SChannel Windows. TLS 1.3 na dziś nie jest wykorzystywany przez SQL, więc standardem pozostaje **TLS 1.2**.

---

## 1) Włącz TLS 1.2 / wyłącz 1.0 i 1.1 (SChannel)

Na **obu węzłach** (Administrator, PowerShell):

```powershell
$sch='HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

# TLS 1.0 OFF
New-Item -Path "$sch\TLS 1.0\Server" -Force | Out-Null
New-ItemProperty -Path "$sch\TLS 1.0\Server" -Name Enabled -Type DWord -Value 0 -Force | Out-Null
New-ItemProperty -Path "$sch\TLS 1.0\Server" -Name DisabledByDefault -Type DWord -Value 1 -Force | Out-Null

# TLS 1.1 OFF
New-Item -Path "$sch\TLS 1.1\Server" -Force | Out-Null
New-ItemProperty -Path "$sch\TLS 1.1\Server" -Name Enabled -Type DWord -Value 0 -Force | Out-Null
New-ItemProperty -Path "$sch\TLS 1.1\Server" -Name DisabledByDefault -Type DWord -Value 1 -Force | Out-Null

# TLS 1.2 ON
New-Item -Path "$sch\TLS 1.2\Server" -Force | Out-Null
New-ItemProperty -Path "$sch\TLS 1.2\Server" -Name Enabled -Type DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path "$sch\TLS 1.2\Server" -Name DisabledByDefault -Type DWord -Value 0 -Force | Out-Null
```

> Wymagany jest **restart** systemu po zmianach SChannel.

---

## 2) Certyfikat dla instancji i wymuszenie szyfrowania (opcjonalnie)

### Wymagania certyfikatu
- EKU **Server Authentication (1.3.6.1.5.5.7.3.1)**
- Private key exportable (niekoniecznie, ale bywa praktyczne)
- `CN` = `SQLSRV-FCI.sqlmaniak.blog` (lub SAN zawierający FQDN VNN)
- Klucz minimum 2048-bit (RSA)

### Ustawienie certyfikatu i Force Encryption via PowerShell
Znajdź odcisk palca („Thumbprint”) z lokalnego „Local Computer\Personal\Certificates” i ustaw:

```powershell
$thumb = '‎PASTE_THUMBPRINT_WITHOUT_SPACES'
$reg = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\SuperSocketNetLib'
Set-ItemProperty -Path $reg -Name "Certificate" -Value $thumb
Set-ItemProperty -Path $reg -Name "ForceEncryption" -Value 1 -Type DWord

# restart zasobu SQL w klastrze
Stop-ClusterResource "SQL Server (MSSQLSERVER)"; Start-ClusterResource "SQL Server (MSSQLSERVER)"
```

> Alternatywnie użyj `scripts/sql/Force-Encryption-SetCert.ps1` z tego repo.

---

## 3) Test po twardnieniu TLS
```powershell
# Sprawdzenie nasłuchu po restarcie
Get-NetTCPConnection -State Listen -LocalPort 1433

# Z klienta z włączonym TLS 1.2:
sqlcmd -S SQLSRV-FCI -Q "SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id=@@SPID;"
```

Jeżeli klienci legacy używają tylko TLS 1.0/1.1 – po wdrożeniu nie połączą się. Zaplanuj okno i rollback (przywrócenie „Enabled=1” dla TLS 1.0/1.1).