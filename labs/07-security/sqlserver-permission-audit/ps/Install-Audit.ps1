param(
    [Parameter(Mandatory=$true)][string]$Instance,
    [Parameter(Mandatory=$true)][string]$AuditPath,
    [string]$AuditName = "Audit_PermChanges",
    [string]$ServerSpecName = "SAS_PermChanges",
    [string[]]$Databases = @(),
    [switch]$IncludeServerSpec
)

function Invoke-SqlFile {
    param([string]$File, [hashtable]$Vars)
    $varArgs = @()
    foreach ($k in $Vars.Keys) { $varArgs += @('-v', ("{0}={1}" -f $k, $Vars[$k])) }
    $psi = @('-S', $Instance, '-E', '-b', '-l', '30', '-i', $File) + $varArgs
    & sqlcmd @psi
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed for $File" }
}

Write-Host "==> Creating/Enabling SERVER AUDIT on $Instance to $AuditPath" -ForegroundColor Cyan
Invoke-SqlFile -File ".\sql\CreateServerAudit.sql" -Vars @{ AuditName=$AuditName; AuditPath=$AuditPath }

if ($IncludeServerSpec) {
    Write-Host "==> Creating SERVER AUDIT SPEC (server-level)" -ForegroundColor Cyan
    Invoke-SqlFile -File ".\sql\CreateServerAuditSpec.sql" -Vars @{ AuditName=$AuditName; ServerSpecName=$ServerSpecName }
}

foreach ($db in $Databases) {
    Write-Host "==> Creating DB AUDIT SPEC in [$db]" -ForegroundColor Cyan
    Invoke-SqlFile -File ".\sql\CreateDbAuditSpec.sql" -Vars @{ AuditName=$AuditName; DbName=$db; DbSpecName='DAS_PermChanges' }
}

Write-Host "Done." -ForegroundColor Green
