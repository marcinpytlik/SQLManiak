<#
.SYNOPSIS
    Analizuje pakiet SSIS .dtsx bez Visual Studio/SSDT.

.DESCRIPTION
    Skrypt czyta plik .dtsx jako XML i generuje raporty:
    - Markdown
    - HTML
    - CSV: ConnectionManagers, Executables, Variables, SqlStatements, PackageProperties

.EXAMPLE
    .\Analyze-DtsxPackage.ps1 -DtsxPath "C:\Temp\Pakiet.dtsx" -OutputFolder "C:\Temp\DtsxAnalysis"

.NOTES
    Autor: Duduś dla marcina
    Wymagania: Windows PowerShell 5.1+ lub PowerShell 7+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$DtsxPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = ".\DtsxAnalysis"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-SafeFileName {
    param([string]$Name)
    return ($Name -replace '[\\/:*?"<>|]', '_')
}

function Get-Attr {
    param(
        [Parameter(Mandatory = $true)] $Node,
        [Parameter(Mandatory = $true)] [string]$LocalName
    )

    foreach ($attr in $Node.Attributes) {
        if ($attr.LocalName -eq $LocalName) {
            return $attr.Value
        }
    }

    return $null
}

function Get-NodeText {
    param($Node)

    if ($null -eq $Node) { return $null }

    if ($Node.InnerText) {
        return ($Node.InnerText -replace "`r`n", "`n").Trim()
    }

    return $null
}

function ConvertTo-HtmlTable {
    param(
        [Parameter(Mandatory = $true)] [array]$Data,
        [Parameter(Mandatory = $true)] [string]$Title
    )

    if ($Data.Count -eq 0) {
        return "<h2>$Title</h2><p>Brak danych.</p>"
    }

    return ($Data | ConvertTo-Html -Fragment -PreContent "<h2>$Title</h2>")
}

$resolvedDtsx = (Resolve-Path $DtsxPath).Path
$packageBaseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedDtsx)
$safePackageName = New-SafeFileName $packageBaseName

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$outputResolved = (Resolve-Path $OutputFolder).Path

[xml]$xml = Get-Content -Path $resolvedDtsx -Raw -Encoding UTF8

# Root executable
$root = $xml.DocumentElement

$packageProps = [System.Collections.Generic.List[object]]::new()

$root.Attributes | ForEach-Object {
    $packageProps.Add([PSCustomObject]@{
        Property = $_.LocalName
        Value    = $_.Value
    })
}

# Additional package properties stored as DTS:Property
$xml.SelectNodes("//*[local-name()='Property']") | ForEach-Object {
    $propName = Get-Attr $_ "Name"
    if ($propName) {
        $packageProps.Add([PSCustomObject]@{
            Property = $propName
            Value    = Get-NodeText $_
        })
    }
}

$packageProps = $packageProps |
    Sort-Object Property, Value -Unique

# Connection Managers
$connectionManagers = $xml.SelectNodes("//*[local-name()='ConnectionManager']") | ForEach-Object {
    [PSCustomObject]@{
        Name             = Get-Attr $_ "ObjectName"
        DTSID            = Get-Attr $_ "DTSID"
        CreationName     = Get-Attr $_ "CreationName"
        Description      = Get-Attr $_ "Description"
        ConnectionString = (
            (Get-Attr $_ "ConnectionString"),
            ($_.SelectNodes(".//*[local-name()='Property']") | Where-Object { (Get-Attr $_ "Name") -eq "ConnectionString" } | Select-Object -First 1 | ForEach-Object { Get-NodeText $_ })
        ) | Where-Object { $_ } | Select-Object -First 1
    }
} | Sort-Object Name

# Executables / Tasks
$executables = $xml.SelectNodes("//*[local-name()='Executable']") | ForEach-Object {
    [PSCustomObject]@{
        Name           = Get-Attr $_ "ObjectName"
        ExecutableType = Get-Attr $_ "ExecutableType"
        CreationName   = Get-Attr $_ "CreationName"
        DTSID          = Get-Attr $_ "DTSID"
        Description    = Get-Attr $_ "Description"
    }
} | Sort-Object Name

# Variables
$variables = $xml.SelectNodes("//*[local-name()='Variable']") | ForEach-Object {
    $valueNode = $_.SelectSingleNode(".//*[local-name()='VariableValue']")
    [PSCustomObject]@{
        Namespace = Get-Attr $_ "Namespace"
        Name      = Get-Attr $_ "ObjectName"
        DataType  = Get-Attr $valueNode "DataType"
        Value     = Get-NodeText $valueNode
        DTSID     = Get-Attr $_ "DTSID"
    }
} | Sort-Object Namespace, Name

# SQL statements and interesting text
$sqlRegex = '(?is)\b(SELECT|INSERT|UPDATE|DELETE|MERGE|EXEC|EXECUTE|TRUNCATE|CREATE|ALTER|DROP|WITH|DECLARE)\b'

$sqlStatements = [System.Collections.Generic.List[object]]::new()

$xml.SelectNodes("//*[local-name()='Property']") | ForEach-Object {
    $name = Get-Attr $_ "Name"
    $text = Get-NodeText $_

    if ($text -and ($text -match $sqlRegex -or $name -match 'Sql|Statement|Command|Query')) {
        $parent = $_.ParentNode
        $sqlStatements.Add([PSCustomObject]@{
            PropertyName = $name
            ParentName   = Get-Attr $parent "ObjectName"
            ParentType   = Get-Attr $parent "ExecutableType"
            Text         = $text
        })
    }
}

# Expressions
$expressions = $xml.SelectNodes("//*[local-name()='PropertyExpression']") | ForEach-Object {
    [PSCustomObject]@{
        Name       = Get-Attr $_ "Name"
        ParentName = Get-Attr $_.ParentNode "ObjectName"
        Expression = Get-NodeText $_
    }
} | Sort-Object ParentName, Name

# Event handlers
$eventHandlers = $xml.SelectNodes("//*[local-name()='EventHandler']") | ForEach-Object {
    [PSCustomObject]@{
        Name      = Get-Attr $_ "ObjectName"
        EventName = Get-Attr $_ "EventName"
        DTSID     = Get-Attr $_ "DTSID"
    }
} | Sort-Object Name

# Precedence constraints
$precedenceConstraints = $xml.SelectNodes("//*[local-name()='PrecedenceConstraint']") | ForEach-Object {
    [PSCustomObject]@{
        Name        = Get-Attr $_ "ObjectName"
        From        = Get-Attr $_ "From"
        To          = Get-Attr $_ "To"
        Value       = Get-Attr $_ "Value"
        EvalOp      = Get-Attr $_ "EvalOp"
        Expression  = Get-Attr $_ "Expression"
    }
} | Sort-Object Name

# Warnings / quick findings
$warnings = [System.Collections.Generic.List[string]]::new()

$protectionLevel = ($packageProps | Where-Object { $_.Property -eq "ProtectionLevel" } | Select-Object -First 1).Value
if ($protectionLevel) {
    $warnings.Add("ProtectionLevel: $protectionLevel")
}

$encryptedOrPassword = $xml.OuterXml | Select-String -Pattern 'Encrypt|Password|Pwd|Sensitive' -AllMatches
if ($encryptedOrPassword.Matches.Count -gt 0) {
    $warnings.Add("W pliku znaleziono odniesienia do Encrypt/Password/Pwd/Sensitive. Sprawdź, czy hasła nie są ukryte albo zależne od ProtectionLevel.")
}

if (($connectionManagers | Where-Object { $_.ConnectionString -match 'Password|Pwd' }).Count -gt 0) {
    $warnings.Add("Connection string może zawierać hasło. Nie publikuj raportów bez anonimizacji.")
}

if (($sqlStatements | Where-Object { $_.Text -match 'TRUNCATE|DELETE\s+FROM|DROP\s+TABLE|ALTER\s+TABLE' }).Count -gt 0) {
    $warnings.Add("W SQL-ach znaleziono potencjalnie destrukcyjne operacje: TRUNCATE/DELETE/DROP/ALTER.")
}

# Export CSV
$packageProps | Export-Csv -Path (Join-Path $outputResolved "$safePackageName.PackageProperties.csv") -NoTypeInformation -Encoding UTF8
$connectionManagers | Export-Csv -Path (Join-Path $outputResolved "$safePackageName.ConnectionManagers.csv") -NoTypeInformation -Encoding UTF8
$executables | Export-Csv -Path (Join-Path $outputResolved "$safePackageName.Executables.csv") -NoTypeInformation -Encoding UTF8
$variables | Export-Csv -Path (Join-Path $outputResolved "$safePackageName.Variables.csv") -NoTypeInformation -Encoding UTF8
$sqlStatements | Export-Csv -Path (Join-Path $outputResolved "$safePackageName.SqlStatements.csv") -NoTypeInformation -Encoding UTF8
$expressions | Export-Csv -Path (Join-Path $outputResolved "$safePackageName.Expressions.csv") -NoTypeInformation -Encoding UTF8
$eventHandlers | Export-Csv -Path (Join-Path $outputResolved "$safePackageName.EventHandlers.csv") -NoTypeInformation -Encoding UTF8
$precedenceConstraints | Export-Csv -Path (Join-Path $outputResolved "$safePackageName.PrecedenceConstraints.csv") -NoTypeInformation -Encoding UTF8

# Markdown report
$mdPath = Join-Path $outputResolved "$safePackageName.Report.md"

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Analiza pakietu SSIS DTSX")
[void]$md.AppendLine("")
[void]$md.AppendLine("**Plik:** `$resolvedDtsx`")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Szybkie ostrzeżenia")
[void]$md.AppendLine("")
if ($warnings.Count -eq 0) {
    [void]$md.AppendLine("Brak oczywistych ostrzeżeń.")
} else {
    foreach ($w in $warnings) {
        [void]$md.AppendLine("- $w")
    }
}
[void]$md.AppendLine("")
[void]$md.AppendLine("## Podsumowanie")
[void]$md.AppendLine("")
[void]$md.AppendLine("| Obszar | Liczba |")
[void]$md.AppendLine("|---|---:|")
[void]$md.AppendLine("| Connection Managers | $($connectionManagers.Count) |")
[void]$md.AppendLine("| Executables / Tasks | $($executables.Count) |")
[void]$md.AppendLine("| Variables | $($variables.Count) |")
[void]$md.AppendLine("| SQL Statements | $($sqlStatements.Count) |")
[void]$md.AppendLine("| Expressions | $($expressions.Count) |")
[void]$md.AppendLine("| Event Handlers | $($eventHandlers.Count) |")
[void]$md.AppendLine("| Precedence Constraints | $($precedenceConstraints.Count) |")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Connection Managers")
[void]$md.AppendLine("")
foreach ($cm in $connectionManagers) {
    [void]$md.AppendLine("### $($cm.Name)")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("- CreationName: `$($cm.CreationName)`")
    [void]$md.AppendLine("- ConnectionString: `$($cm.ConnectionString)`")
    [void]$md.AppendLine("")
}
[void]$md.AppendLine("## Tasks / Executables")
[void]$md.AppendLine("")
foreach ($e in $executables) {
    [void]$md.AppendLine("- **$($e.Name)** — `$($e.ExecutableType)` / `$($e.CreationName)`")
}
[void]$md.AppendLine("")
[void]$md.AppendLine("## SQL Statements")
[void]$md.AppendLine("")
foreach ($s in $sqlStatements) {
    [void]$md.AppendLine("### $($s.ParentName) / $($s.PropertyName)")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("```sql")
    [void]$md.AppendLine($s.Text)
    [void]$md.AppendLine("```")
    [void]$md.AppendLine("")
}
[void]$md.AppendLine("## Variables")
[void]$md.AppendLine("")
foreach ($v in $variables) {
    [void]$md.AppendLine("- `$($v.Namespace)::$($v.Name)` = `$($v.Value)` [$($v.DataType)]")
}
[void]$md.AppendLine("")
[void]$md.AppendLine("## Expressions")
[void]$md.AppendLine("")
foreach ($ex in $expressions) {
    [void]$md.AppendLine("- **$($ex.ParentName)** / `$($ex.Name)` = `$($ex.Expression)`")
}

$md.ToString() | Set-Content -Path $mdPath -Encoding UTF8

# HTML report
$htmlPath = Join-Path $outputResolved "$safePackageName.Report.html"

$style = @"
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; }
h1 { color: #333; }
h2 { margin-top: 32px; border-bottom: 1px solid #ddd; padding-bottom: 4px; }
table { border-collapse: collapse; width: 100%; margin-bottom: 24px; }
th, td { border: 1px solid #ddd; padding: 6px; vertical-align: top; }
th { background: #f3f3f3; }
pre { background: #f7f7f7; border: 1px solid #ddd; padding: 10px; white-space: pre-wrap; }
.warning { background: #fff4ce; border: 1px solid #ffb900; padding: 10px; margin-bottom: 10px; }
</style>
"@

$sqlHtml = "<h2>SQL Statements</h2>"
if ($sqlStatements.Count -eq 0) {
    $sqlHtml += "<p>Brak danych.</p>"
} else {
    foreach ($s in $sqlStatements) {
        $safeText = [System.Net.WebUtility]::HtmlEncode($s.Text)
        $sqlHtml += "<h3>$([System.Net.WebUtility]::HtmlEncode($s.ParentName)) / $([System.Net.WebUtility]::HtmlEncode($s.PropertyName))</h3><pre>$safeText</pre>"
    }
}

$warningHtml = "<h2>Szybkie ostrzeżenia</h2>"
if ($warnings.Count -eq 0) {
    $warningHtml += "<p>Brak oczywistych ostrzeżeń.</p>"
} else {
    foreach ($w in $warnings) {
        $warningHtml += "<div class='warning'>$([System.Net.WebUtility]::HtmlEncode($w))</div>"
    }
}

$html = @"
<html>
<head>
<meta charset="utf-8">
<title>Analiza DTSX - $safePackageName</title>
$style
</head>
<body>
<h1>Analiza pakietu SSIS DTSX</h1>
<p><strong>Plik:</strong> $([System.Net.WebUtility]::HtmlEncode($resolvedDtsx))</p>
$warningHtml
$(ConvertTo-HtmlTable -Data @([PSCustomObject]@{
    ConnectionManagers = $connectionManagers.Count
    Executables = $executables.Count
    Variables = $variables.Count
    SqlStatements = $sqlStatements.Count
    Expressions = $expressions.Count
    EventHandlers = $eventHandlers.Count
    PrecedenceConstraints = $precedenceConstraints.Count
}) -Title "Podsumowanie")
$(ConvertTo-HtmlTable -Data $connectionManagers -Title "Connection Managers")
$(ConvertTo-HtmlTable -Data $executables -Title "Tasks / Executables")
$(ConvertTo-HtmlTable -Data $variables -Title "Variables")
$(ConvertTo-HtmlTable -Data $expressions -Title "Expressions")
$(ConvertTo-HtmlTable -Data $eventHandlers -Title "Event Handlers")
$(ConvertTo-HtmlTable -Data $precedenceConstraints -Title "Precedence Constraints")
$sqlHtml
$(ConvertTo-HtmlTable -Data $packageProps -Title "Package Properties")
</body>
</html>
"@

$html | Set-Content -Path $htmlPath -Encoding UTF8

Write-Host ""
Write-Host "Analiza gotowa." -ForegroundColor Green
Write-Host "Folder raportu: $outputResolved"
Write-Host ""
Write-Host "Najważniejsze pliki:"
Write-Host " - $mdPath"
Write-Host " - $htmlPath"
Write-Host ""
