param(
    [string]$InstanceName = "MSSQLSERVER"  # MSSQLSERVER (domyślna) lub MSSQL$Nazwa
)

# Wylicz nazwy usług dla instancji domyślnej/nazwanej
if ($InstanceName -eq "MSSQLSERVER") {
    $engineService = "MSSQLSERVER"
    $agentService  = "SQLSERVERAGENT"
} else {
    # Użytkownik może podać tylko nazwę instancji (np. DEV) lub pełną "MSSQL$DEV"
    if ($InstanceName -notmatch "^MSSQL\$.+") { $InstanceName = "MSSQL$${InstanceName}" }
    $engineService = $InstanceName
    $suffix = $InstanceName -replace "^MSSQL\$", ""
    $agentService  = "SQLAgent$${suffix}"
}

Write-Host "Restarting services: $engineService and $agentService" -ForegroundColor Cyan

Restart-Service -Name $engineService -Force -ErrorAction Stop
try {
    Restart-Service -Name $agentService -Force -ErrorAction Stop
} catch {
    Write-Warning "Agent service not found or not running: $agentService"
}

Write-Host "Done."
