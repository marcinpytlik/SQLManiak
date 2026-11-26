[CmdletBinding()]
param(
    [ValidateSet('baseline','exhaustion','transaction','blocking','rollback')]
    [string[]]$Scenario = @('baseline','exhaustion','transaction','blocking','rollback'),
    [switch]$Counters,
    [switch]$XE
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
$oldPassword = $env:SQLCMDPASSWORD
try {
    if (-not $env:LAB_PASSWORD) { throw 'Set LAB_PASSWORD first' }
    $env:SQLCMDPASSWORD = $env:LAB_PASSWORD
    $null = Get-Command sqlcmd
    if ($Counters) { $null = Get-Command dotnet-counters }
    dotnet build -c Release
    if ($LASTEXITCODE) { throw 'Build failed' }
    $root = Join-Path $PWD ('results/' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff'))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    function Invoke-LabSql {
        param([string[]]$SqlArgs)
        & sqlcmd -S '127.0.0.1,15468' -U sa -d tempdb -C -b -l 5 -t 10 @SqlArgs
        if ($LASTEXITCODE) { throw "sqlcmd failed: $LASTEXITCODE" }
    }
    Invoke-LabSql -SqlArgs @('-Q','SELECT @@VERSION;') | Set-Content (Join-Path $root 'sql-version.log')
    dotnet list package --include-transitive | Set-Content (Join-Path $root 'packages.log')
    foreach ($s in $Scenario) {
        $app = Join-Path $root "$s-app.log"
        $err = Join-Path $root "$s-error.log"
        $dmv = Join-Path $root "$s-dmv.log"
        $proc = $null; $counter = $null; $xeStarted = $false
        try {
            if ($XE) {
                Invoke-LabSql -SqlArgs @('-i','xe.sql')
                $xeStarted = $true
            }
            # Launch DLL directly so the process ID is the actual application PID.
            $proc = Start-Process dotnet -ArgumentList @('bin/Release/net10.0/Lab68.dll',$s) -RedirectStandardOutput $app -RedirectStandardError $err -NoNewWindow -PassThru
            if ($Counters) {
                $counter = Start-Process dotnet-counters -ArgumentList @('collect','--process-id',"$($proc.Id)",'--counters','Microsoft.Data.SqlClient.EventSource','--format','csv','--output',('"' + (Join-Path $root "$s-counters.csv") + '"')) -NoNewWindow -PassThru
            }
            while (-not $proc.HasExited) {
                [DateTime]::UtcNow.ToString('o') | Add-Content $dmv
                Invoke-LabSql -SqlArgs @('-i','observe.sql','-W','-s','|') | Add-Content $dmv
                Start-Sleep -Seconds 1
                $proc.Refresh()
            }
            $proc.WaitForExit()
            Get-Content $app
            Get-Content $err
            if ($proc.ExitCode -ne 0) { throw "$s failed: $($proc.ExitCode)" }
            if ($XE) {
                Invoke-LabSql -SqlArgs @('-y','0','-Q',"SET NOCOUNT ON; SELECT CAST(t.target_data AS nvarchar(max)) FROM sys.dm_xe_session_targets t JOIN sys.dm_xe_sessions s ON s.address=t.event_session_address WHERE s.name=N'Lab68';") | Set-Content (Join-Path $root "$s-xe.log")
            }
        } finally {
            if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
            if ($counter -and -not $counter.WaitForExit(5000)) { Stop-Process -Id $counter.Id -Force }
            if ($xeStarted) { Invoke-LabSql -SqlArgs @('-Q','DROP EVENT SESSION Lab68 ON SERVER;') }
        }
    }
    Write-Host "Results: $root"
} finally {
    $env:SQLCMDPASSWORD = $oldPassword
    Pop-Location
}
