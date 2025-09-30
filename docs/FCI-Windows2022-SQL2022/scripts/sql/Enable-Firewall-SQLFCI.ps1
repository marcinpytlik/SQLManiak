# Włączenie reguł zapory dla SQL/WSFC i jawny 1433 (Domain)
Get-NetFirewallRule -DisplayGroup "SQL Server" | Enable-NetFirewallRule
Get-NetFirewallRule -DisplayGroup "Failover Cluster" | Enable-NetFirewallRule
if (-not (Get-NetFirewallRule -DisplayName "SQL FCI 1433 (Domain, 192.168.11.0/24)" -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName "SQL FCI 1433 (Domain, 192.168.11.0/24)" `
    -Direction Inbound -Protocol TCP -LocalPort 1433 `
    -Profile Domain -Action Allow -RemoteAddress 192.168.11.0/24 | Out-Null
}
