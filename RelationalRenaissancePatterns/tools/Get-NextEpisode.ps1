param(
    [string]$RoadmapPath = (Join-Path $PSScriptRoot '..\ROADMAP.md')
)

$items = Get-Content $RoadmapPath |
    Where-Object { $_ -match '^\d{2}\.' }

$items | ForEach-Object {
    [PSCustomObject]@{
        Week = [int]($_.Substring(0,2))
        Topic = ($_ -replace '^\d{2}\.\s+\*\*','' -replace '\*\*.*$','')
        Line = $_
    }
} | Format-Table -AutoSize
