<#
.SYNOPSIS
    Wyciąga same zapytania SQL z pakietu .dtsx do osobnych plików .sql.

.EXAMPLE
    .\Extract-DtsxSqlStatements.ps1 -DtsxPath "C:\Temp\Pakiet.dtsx" -OutputFolder "C:\Temp\DtsxSql"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$DtsxPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = ".\DtsxSql"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Attr {
    param($Node, [string]$LocalName)
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
    return ($Node.InnerText -replace "`r`n", "`n").Trim()
}

function New-SafeFileName {
    param([string]$Name)
    $safe = ($Name -replace '[\\/:*?"<>|]', '_')
    if ([string]::IsNullOrWhiteSpace($safe)) { return "Unknown" }
    return $safe
}

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$outputResolved = (Resolve-Path $OutputFolder).Path

[xml]$xml = Get-Content -Path $DtsxPath -Raw -Encoding UTF8

$sqlRegex = '(?is)\b(SELECT|INSERT|UPDATE|DELETE|MERGE|EXEC|EXECUTE|TRUNCATE|CREATE|ALTER|DROP|WITH|DECLARE)\b'
$counter = 1

$xml.SelectNodes("//*[local-name()='Property']") | ForEach-Object {
    $name = Get-Attr $_ "Name"
    $text = Get-NodeText $_

    if ($text -and ($text -match $sqlRegex -or $name -match 'Sql|Statement|Command|Query')) {
        $parent = $_.ParentNode
        $parentName = Get-Attr $parent "ObjectName"
        $fileName = "{0:000}_{1}_{2}.sql" -f $counter, (New-SafeFileName $parentName), (New-SafeFileName $name)
        $target = Join-Path $outputResolved $fileName

        $header = @"
/*
Źródło DTSX: $DtsxPath
Task/Parent: $parentName
Property: $name
Wyciągnięto: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
*/

"@

        ($header + $text) | Set-Content -Path $target -Encoding UTF8
        $counter++
    }
}

Write-Host ""
Write-Host "Wyciągnięto SQL-e: $($counter - 1)" -ForegroundColor Green
Write-Host "Folder: $outputResolved"
