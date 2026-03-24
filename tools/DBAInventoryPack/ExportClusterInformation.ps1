#requires -Version 5.1

[CmdletBinding()]
param(
    [string[]]$ClusterNames = @(),
    [string]$OutputCsv = "C:\Temp\SqlFciClusterReport.csv"
)

function Get-SqlFciClusterReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ClusterName
    )

    try {
        $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
    }
    catch {
        Write-Warning "Nie udało się pobrać klastra '$ClusterName'. $_"
        return @()
    }

    try {
        $nodes = Get-ClusterNode -Cluster $ClusterName -ErrorAction Stop
    }
    catch {
        Write-Warning "Nie udało się pobrać węzłów dla '$ClusterName'. $_"
        $nodes = @()
    }

    try {
        $groups = Get-ClusterGroup -Cluster $ClusterName -ErrorAction Stop
    }
    catch {
        Write-Warning "Nie udało się pobrać grup dla '$ClusterName'. $_"
        return @()
    }

    $result = foreach ($group in $groups) {
        try {
            $resources = Get-ClusterResource -Cluster $ClusterName -ErrorAction Stop |
                Where-Object { $_.OwnerGroup -eq $group.Name }
        }
        catch {
            Write-Warning "Nie udało się pobrać zasobów dla grupy '$($group.Name)'. $_"
            continue
        }

        $sqlResources = $resources | Where-Object { $_.ResourceType -match 'SQL Server' }
        if (-not $sqlResources) {
            continue
        }

        $agentResources = $resources | Where-Object { $_.ResourceType -match 'SQL Server Agent' }
        $networkNameResources = $resources | Where-Object { $_.ResourceType -eq 'Network Name' }
        $ipResources = $resources | Where-Object { $_.ResourceType -eq 'IP Address' }
        $diskResources = $resources | Where-Object { $_.ResourceType -match 'Physical Disk|Disk' }

        $instanceNames = foreach ($res in $sqlResources) {
            $instanceName = $null

            try {
                $privateParams = Get-ClusterParameter -InputObject $res -ErrorAction Stop
                $instanceParam = $privateParams | Where-Object { $_.Name -match 'InstanceName' }
                if ($instanceParam) {
                    $instanceName = $instanceParam.Value
                }
            }
            catch {
            }

            if (-not $instanceName) {
                if ($res.Name -match 'SQL Server \((.+?)\)') {
                    $instanceName = $Matches[1]
                }
                elseif ($res.Name -match 'SQL Server Agent \((.+?)\)') {
                    $instanceName = $Matches[1]
                }
                else {
                    $instanceName = 'MSSQLSERVER lub nieustalona'
                }
            }

            $instanceName
        } | Sort-Object -Unique

        $ipAddresses = foreach ($ip in $ipResources) {
            try {
                $params = Get-ClusterParameter -InputObject $ip -ErrorAction Stop
                ($params | Where-Object Name -eq 'Address').Value
            }
            catch {
                $null
            }
        }

        [PSCustomObject]@{
            ClusterName       = $cluster.Name
            ClusterState      = $cluster.State
            GroupName         = $group.Name
            GroupState        = $group.State
            ActiveNode        = $group.OwnerNode.Name
            UpNodes           = (($nodes | Where-Object State -eq 'Up' | Select-Object -ExpandProperty Name) -join '; ')
            SqlInstanceNames  = ($instanceNames -join '; ')
            SqlResources      = (($sqlResources | Select-Object -ExpandProperty Name) -join '; ')
            AgentResources    = (($agentResources | Select-Object -ExpandProperty Name) -join '; ')
            NetworkNames      = (($networkNameResources | Select-Object -ExpandProperty Name) -join '; ')
            IpAddresses       = ($ipAddresses -join '; ')
            DiskResources     = (($diskResources | Select-Object -ExpandProperty Name) -join '; ')
            AllResources      = (($resources | Select-Object -ExpandProperty Name) -join '; ')
            CollectedAt       = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }

    return $result
}

try {
    Import-Module FailoverClusters -ErrorAction Stop
}
catch {
    throw "Nie udało się załadować modułu FailoverClusters. $_"
}

if (-not $ClusterNames -or $ClusterNames.Count -eq 0) {
    try {
        $ClusterNames = @((Get-Cluster).Name)
    }
    catch {
        throw "Nie podano -ClusterNames i nie udało się wykryć lokalnego klastra."
    }
}

$allResults = foreach ($clusterName in $ClusterNames) {
    Get-SqlFciClusterReport -ClusterName $clusterName
}

if (-not $allResults -or $allResults.Count -eq 0) {
    Write-Warning "Nie znaleziono żadnych ról SQL Server FCI."
    return
}

$folder = Split-Path -Path $OutputCsv -Parent
if (-not [string]::IsNullOrWhiteSpace($folder) -and -not (Test-Path $folder)) {
    New-Item -Path $folder -ItemType Directory -Force | Out-Null
}

$allResults |
    Sort-Object ClusterName, GroupName |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Raport zapisany do: $OutputCsv" -ForegroundColor Green
$allResults | Format-Table ClusterName, GroupName, SqlInstanceNames, ActiveNode, GroupState, NetworkNames, IpAddresses -AutoSize