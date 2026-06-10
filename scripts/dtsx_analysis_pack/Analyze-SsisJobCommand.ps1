<#
.SYNOPSIS
    Analizuje komendę SQL Agent job step dla pakietu SSIS.

.DESCRIPTION
    Skrypt wyciąga z komendy joba najważniejsze przełączniki:
    /SQL, /FILE, /SERVER, /CONFIGFILE, /SET, /CONNECTION, /DECRYPT, /CHECKPOINTING, /REPORTING

.EXAMPLE
    .\Analyze-SsisJobCommand.ps1 -CommandLine '/SQL "\Folder\Pakiet" /SERVER "SQL01\INST" /CONFIGFILE "C:\cfg.dtsConfig"'

.EXAMPLE
    Get-Content .\job_step_command.txt -Raw | .\Analyze-SsisJobCommand.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [string]$CommandLine,

    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = ".\DtsxAnalysis"
)

begin {
    $chunks = New-Object System.Collections.Generic.List[string]
}

process {
    if ($CommandLine) {
        $chunks.Add($CommandLine)
    }
}

end {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    if ($chunks.Count -eq 0) {
        throw "Podaj -CommandLine albo przekaż treść przez pipeline."
    }

    $cmd = ($chunks -join "`n").Trim()

    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    $outputResolved = (Resolve-Path $OutputFolder).Path

    function Get-SwitchValues {
        param(
            [string]$Text,
            [string]$SwitchName
        )

        $pattern = "(?i)/$SwitchName\s+((`"[^`"]+`")|('[^']+')|(\S+))"
        $matches = [regex]::Matches($Text, $pattern)

        foreach ($m in $matches) {
            $v = $m.Groups[1].Value.Trim()
            $v = $v.Trim('"').Trim("'")
            $v
        }
    }

    $switches = @(
        "SQL",
        "FILE",
        "DTS",
        "SERVER",
        "SOURCE_SERVER",
        "CONFIGFILE",
        "CONNECTION",
        "SET",
        "DECRYPT",
        "CHECKPOINTING",
        "REPORTING",
        "MAXCONCURRENT",
        "VALIDATE"
    )

    $results = foreach ($s in $switches) {
        $values = @(Get-SwitchValues -Text $cmd -SwitchName $s)
        if ($values.Count -eq 0) {
            [PSCustomObject]@{
                Switch = "/$s"
                Found  = $false
                Value  = $null
            }
        } else {
            foreach ($v in $values) {
                [PSCustomObject]@{
                    Switch = "/$s"
                    Found  = $true
                    Value  = $v
                }
            }
        }
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $csv = Join-Path $outputResolved "JobCommandAnalysis_$timestamp.csv"
    $md  = Join-Path $outputResolved "JobCommandAnalysis_$timestamp.md"

    $results | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Analiza komendy SQL Agent SSIS job step")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Oryginalna komenda")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("```text")
    [void]$sb.AppendLine($cmd)
    [void]$sb.AppendLine("```")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Wykryte parametry")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Przełącznik | Znaleziono | Wartość |")
    [void]$sb.AppendLine("|---|---:|---|")

    foreach ($r in $results) {
        $value = if ($r.Value) { $r.Value.Replace("|", "\|") } else { "" }
        [void]$sb.AppendLine("| $($r.Switch) | $($r.Found) | `$value` |")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Co jest krytyczne przy analizie")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("- `/SQL`, `/DTS` albo `/FILE` pokazuje, skąd job bierze pakiet.")
    [void]$sb.AppendLine("- `/SERVER` pokazuje instancję SQL Server/MSDB.")
    [void]$sb.AppendLine("- `/CONFIGFILE` może nadpisywać connection stringi i zmienne.")
    [void]$sb.AppendLine("- `/SET` może nadpisywać właściwości pakietu w runtime.")
    [void]$sb.AppendLine("- `/CONNECTION` może nadpisywać connection managera.")
    [void]$sb.AppendLine("- `/DECRYPT` oznacza użycie hasła do odszyfrowania pakietu.")

    $sb.ToString() | Set-Content -Path $md -Encoding UTF8

    Write-Host ""
    Write-Host "Analiza komendy joba gotowa." -ForegroundColor Green
    Write-Host "Folder raportu: $outputResolved"
    Write-Host " - $csv"
    Write-Host " - $md"
}
