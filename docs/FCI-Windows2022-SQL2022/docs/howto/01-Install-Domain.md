# Instalacja domeny (AD DS + DNS)
Uruchom na przyszłym DC (Windows Server), jako Administrator:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
.\scripts\dc\installDomain.ps1 -DomainName 'sqlmaniak.blog' -IPv4Address '192.168.11.1' -PrefixLength 24
# po restarcie (na DC):
Add-DnsServerForwarder -IPAddress 1.1.1.1,8.8.8.8
Add-DnsServerPrimaryZone -NetworkId "192.168.11.0/24" -ReplicationScope "Domain"
```
