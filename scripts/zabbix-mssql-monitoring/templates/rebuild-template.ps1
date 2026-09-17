$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Packed = Join-Path $Root 'packed'
$Out = Join-Path $Root 'SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly.yaml'
$Expected = '2b47546f54ad8e9aaa78fb1ebec7b7f51ab044d137abedc6a0bf041cf500f40d'

$b64 = (Get-ChildItem -Path $Packed -Filter 'part-*.b64' | Sort-Object Name | Get-Content -Raw) -join ''
$compressed = [Convert]::FromBase64String(($b64 -replace '\s',''))

$input = New-Object System.IO.MemoryStream(,$compressed)
$gzip = New-Object System.IO.Compression.GzipStream($input,[System.IO.Compression.CompressionMode]::Decompress)
$output = [System.IO.File]::Create($Out)
try {
    $gzip.CopyTo($output)
}
finally {
    $output.Dispose()
    $gzip.Dispose()
    $input.Dispose()
}

$Actual = (Get-FileHash -Path $Out -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Actual -ne $Expected) {
    throw "SHA256 mismatch. Expected $Expected, actual $Actual"
}

Write-Host "OK: $Out"
Write-Host "SHA256: $Actual"
