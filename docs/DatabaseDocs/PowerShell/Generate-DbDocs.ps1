param(
    [string]$ServerInstance = "localhost",
    [string]$Database = "AdventureWorks2022",
    [string]$OutputRoot = ".\Docs"
)

Import-Module SqlServer -ErrorAction Stop

# Prepare paths
$OutDir = Join-Path $OutputRoot $Database
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Helper: run T-SQL and return DataTable
function Run-Sql([string]$q) {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $q -QueryTimeout 0
}

# 1) Export CSVs
$tables    = Run-Sql (Get-Content ".\Scripts\Dictionary_Tables.sql" -Raw)
$views     = Run-Sql (Get-Content ".\Scripts\Dictionary_Views.sql" -Raw)
$procs     = Run-Sql (Get-Content ".\Scripts\Dictionary_Procedures.sql" -Raw)
$fks       = Run-Sql (Get-Content ".\Scripts\Dictionary_FKs.sql" -Raw)
$erd       = Run-Sql (Get-Content ".\Scripts\GraphViz_ERD_DOT.sql" -Raw)

$tables | Export-Csv (Join-Path $OutDir "Tables.csv") -NoTypeInformation -Encoding UTF8
# Columns are embedded in Tables.sql output's second result set (run separately for clarity)
$columns = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query @"
SELECT 
    s.name  AS schema_name,
    t.name  AS table_name,
    c.column_id,
    c.name  AS column_name,
    ty.name AS data_type,
    c.max_length, c.precision, c.scale,
    c.is_nullable,
    dc.definition AS default_definition,
    ep_c.value AS column_description
FROM sys.tables t
JOIN sys.schemas s  ON s.schema_id = t.schema_id
JOIN sys.columns c  ON c.object_id = t.object_id
JOIN sys.types   ty ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints dc ON dc.parent_object_id = t.object_id AND dc.parent_column_id = c.column_id
LEFT JOIN sys.extended_properties ep_c 
    ON ep_c.major_id = c.object_id AND ep_c.minor_id = c.column_id AND ep_c.name = 'MS_Description'
ORDER BY s.name, t.name, c.column_id;
"@
$columns | Export-Csv (Join-Path $OutDir "Columns.csv") -NoTypeInformation -Encoding UTF8
$views  | Export-Csv (Join-Path $OutDir "Views.csv") -NoTypeInformation -Encoding UTF8
$procs  | Export-Csv (Join-Path $OutDir "Procedures.csv") -NoTypeInformation -Encoding UTF8
$fks    | Export-Csv (Join-Path $OutDir "ForeignKeys.csv") -NoTypeInformation -Encoding UTF8

# 2) Write ERD DOT
$erdFile = Join-Path $OutDir "ERD.dot"
$erd.ERD_DOT | Out-File -FilePath $erdFile -Encoding UTF8

# 3) Generate Markdown files
$header = (Get-Content ".\Templates\Markdown_Header.md" -Raw) -replace "{date}", (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$ddFile = Join-Path $OutDir "DataDictionary.md"
$tblMd  = Join-Path $OutDir "01_Tables.md"
$vwMd   = Join-Path $OutDir "02_Views.md"
$prMd   = Join-Path $OutDir "03_Procedures.md"
$fkMd   = Join-Path $OutDir "04_Constraints.md"

# DataDictionary.md
$dict = @()
$dict += $header
$dict += "# Data Dictionary – $Database`n"
$dict += "## Spis treści"
$dict += "- [Tabele](01_Tables.md)"
$dict += "- [Widoki](02_Views.md)"
$dict += "- [Procedury](03_Procedures.md)"
$dict += "- [Relacje (FK)](04_Constraints.md)"
$dict += "- ERD (GraphViz DOT): `ERD.dot`"
$dict -join "`n" | Out-File -FilePath $ddFile -Encoding UTF8

# 01_Tables.md
$md = @()
$md += "# Tabele"
$grp = $tables | Select-Object schema_name, table_name, approx_rowcount, table_description -Unique | Sort-Object schema_name, table_name
foreach ($t in $grp) {
    $md += "## $($t.schema_name).$($t.table_name)"
    if ($t.table_description) { $md += "> $($t.table_description)" }
    $md += ""
    $md += "| # | Kolumna | Typ | Null | Domyślna | Opis |"
    $md += "|---|---------|-----|------|----------|------|"
    $cols = $columns | Where-Object { $_.schema_name -eq $t.schema_name -and $_.table_name -eq $t.table_name } | Sort-Object column_id
    $i = 1
    foreach ($c in $cols) {
        $type = $c.data_type
        if ($c.precision -gt 0 -and $c.scale -gt 0) { $type = "$type($($c.precision),$($c.scale))" }
        elseif ($c.max_length -gt 0 -and $c.data_type -match 'char|binary|nchar|nvarchar|varbinary') { 
            $len = if ($c.max_length -eq -1) { "MAX" } elseif ($c.data_type -match '^n') { [int]($c.max_length/2) } else { $c.max_length }
            $type = "$type($len)" 
        }
        $nulls = if ($c.is_nullable) { "NULL" } else { "NOT NULL" }
        $def = if ($c.default_definition) { ($c.default_definition -replace '\s+', ' ') } else { "" }
        $desc = if ($c.column_description) { $c.column_description } else { "" }
        $md += "| $i | $($c.column_name) | $type | $nulls | $def | $desc |"
        $i++
    }
    $md += ""
}
$md -join "`n" | Out-File -FilePath $tblMd -Encoding UTF8

# 02_Views.md
$md = @()
$md += "# Widoki"
foreach ($v in ($views | Sort-Object schema_name, view_name)) {
    $md += "## $($v.schema_name).$($v.view_name)"
    if ($v.description) { $md += "> $($v.description)" }
    if ($v.definition) {
        $md += ""
        $md += "```sql"
        $md += $v.definition
        $md += "```"
    }
    $md += ""
}
$md -join "`n" | Out-File -FilePath $vwMd -Encoding UTF8

# 03_Procedures.md
$md = @()
$md += "# Procedury składowane"
foreach ($p in ($procs | Sort-Object schema_name, proc_name)) {
    $md += "## $($p.schema_name).$($p.proc_name)"
    if ($p.description) { $md += "> $($p.description)" }
    if ($p.definition) {
        $md += ""
        $md += "```sql"
        $md += $p.definition
        $md += "```"
    }
    $md += ""
}
$md -join "`n" | Out-File -FilePath $prMd -Encoding UTF8

# 04_Constraints.md
$md = @()
$md += "# Klucze obce"
$md += "| Tabela | FK | Referencja | Kolumny | Ref.Kolumny |"
$md += "|--------|----|------------|---------|-------------|"
foreach ($r in ($fks | Sort-Object schema_name, table_name, fk_name)) {
    $md += "| $($r.schema_name).$($r.table_name) | $($r.fk_name) | $($r.ref_schema_name).$($r.ref_table_name) | $($r.fk_columns) | $($r.ref_columns) |"
}
$md -join "`n" | Out-File -FilePath $fkMd -Encoding UTF8

Write-Host "Dokumentacja wygenerowana do $OutDir"
