# 🔐 SQL Server 2022 Standalone – Firewall & Konta serwisowe (gMSA)

## 1) Reguły Zapory (TCP 1433 + UDP 1434)
```powershell
# TCP 1433 – silnik SQL (zmień port, jeśli niestandardowy)
New-NetFirewallRule -DisplayName "SQL Server 2022 TCP 1433" `
    -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow

# UDP 1434 – SQL Browser (opcjonalnie, dla instancji nazwanych)
New-NetFirewallRule -DisplayName "SQL Server 2022 UDP 1434" `
    -Direction Inbound -Protocol UDP -LocalPort 1434 -Action Allow
```
> Jeśli używasz innego portu (np. 51433), podmień `-LocalPort`.

## 2) Tworzenie gMSA (na kontrolerze domeny)
```powershell
Import-Module ActiveDirectory

# Grupa serwerów, które mogą pobierać hasło gMSA
New-ADGroup -Name "SQL2022_Servers" -GroupScope Global -Path "OU=Groups,DC=contoso,DC=com"

# Utworzenie konta gMSA
New-ADServiceAccount -Name gmsa-sql2022 `
    -DNSHostName sql2022.contoso.com `
    -PrincipalsAllowedToRetrieveManagedPassword "SQL2022_Servers"

# Dodanie komputera serwera SQL do grupy
Add-ADGroupMember -Identity "SQL2022_Servers" -Members "SQLSRV01$"
```

### Instalacja gMSA na serwerze SQL
```powershell
Install-ADServiceAccount gmsa-sql2022
Test-ADServiceAccount gmsa-sql2022
```
> W instalatorze SQL jako konto usługi użyj: `DOMENA\gmsa-sql2022$` (z dolarowym sufiksem).

## 3) Nadanie praw lokalnych dla konta serwisowego
### Log on as a service
```powershell
# Wymaga narzędzia ntrights.exe (RSAT/AD DS Tools)
ntrights +r SeServiceLogonRight -u CONTOSO\gmsa-sql2022$
```
### Perform volume maintenance tasks (Instant File Initialization)
```powershell
ntrights +r SeManageVolumePrivilege -u CONTOSO\gmsa-sql2022$
```
### Lock pages in memory (opcjonalnie)
```powershell
ntrights +r SeLockMemoryPrivilege -u CONTOSO\gmsa-sql2022$
```

## 4) Szybka kontrola zasad i GPO
```powershell
whoami /groups
gpresult /r
```
