[CmdletBinding()]
param(
    [string]$GrafanaDirectory = (Join-Path $PSScriptRoot 'grafana')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $GrafanaDirectory)) {
    throw "Grafana directory not found: $GrafanaDirectory"
}

# Explicit reporting-area mapping.
# Avoid short ambiguous tokens such as "ha", because "change" contains "ha".
$areas = [ordered]@{
    audit = @(
        'audit',
        'compliance'
    )
    backup = @(
        'backup',
        'recovery'
    )
    capacity = @(
        'capacity',
        'storage',
        'volume'
    )
    config = @(
        'configuration',
        'config drift',
        'configuration drift',
        'tempdb',
        'trace flag',
        'query store',
        'linked server'
    )
    db = @(
        'database',
        'schema changes',
        'table usage'
    )
    ha = @(
        'high availability',
        'availability group',
        'availability groups',
        'replica',
        'failover'
    )
    job = @(
        'sql agent',
        'agent jobs',
        'job compliance',
        'job changes',
        'jobs'
    )
    maintenance = @(
        'maintenance',
        'checkdb',
        'suspect pages',
        'index maintenance'
    )
    patch = @(
        'patch',
        'build compliance',
        'sql build'
    )
    perf = @(
        'performance',
        'workload',
        'collector health',
        'table usage'
    )
    security = @(
        'security',
        'permissions',
        'principals',
        'credentials',
        'proxy'
    )
}

$dashboards = @(
    Get-ChildItem -LiteralPath $GrafanaDirectory -Filter '*.json' -File |
    ForEach-Object {
        try {
            $json = Get-Content -LiteralPath $_.FullName -Raw |
                ConvertFrom-Json -Depth 100

            $title = $null

            if ($null -ne $json.spec -and
                $json.spec.PSObject.Properties.Name -contains 'title') {
                $title = [string]$json.spec.title
            }
            elseif ($json.PSObject.Properties.Name -contains 'title') {
                # Legacy Grafana JSON fallback.
                $title = [string]$json.title
            }

            if ([string]::IsNullOrWhiteSpace($title)) {
                $title = $_.BaseName
            }

            [pscustomobject]@{
                FileName = $_.Name
                Title    = $title
                FullName = $_.FullName
            }
        }
        catch {
            Write-Warning "Cannot parse $($_.FullName): $($_.Exception.Message)"
        }
    }
)

$result = foreach ($area in $areas.Keys) {
    $patterns = $areas[$area]

    $matching = @(
        $dashboards | Where-Object {
            $text = ("{0} {1}" -f $_.FileName, $_.Title).ToLowerInvariant()

            $isMatch = $false

            foreach ($pattern in $patterns) {
                if ($text.Contains($pattern.ToLowerInvariant())) {
                    $isMatch = $true
                    break
                }
            }

            $isMatch
        }
    )

    $matchingTitles = @(
        $matching |
        ForEach-Object { $_.Title } |
        Sort-Object -Unique
    )

    [pscustomobject]@{
        Area                  = $area
        GrafanaDashboardCount = $matching.Count
        GrafanaStatus         = if ($matching.Count -gt 0) {
            'DASHBOARD_EXISTS'
        }
        else {
            'NO_DASHBOARD'
        }
        Dashboards            = ($matchingTitles -join '; ')
    }
}

Write-Host ''
Write-Host '=== Reporting coverage - Grafana ==='
$result |
    Sort-Object Area |
    Format-Table Area, GrafanaDashboardCount, GrafanaStatus, Dashboards -AutoSize

Write-Host ''
Write-Host '=== Dashboards discovered in repository ==='
$dashboards |
    Sort-Object Title |
    Format-Table Title, FileName -AutoSize

Write-Host ''
Write-Host '=== Suspicious / duplicate file names ==='
$suspicious = @(
    $dashboards |
    Where-Object {
        $_.FileName -match '%20|%2D|%[0-9A-Fa-f]{2}'
    }
)

if ($suspicious.Count -eq 0) {
    Write-Host 'None.'
}
else {
    $suspicious |
        Format-Table Title, FileName -AutoSize
}