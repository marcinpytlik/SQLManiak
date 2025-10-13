# ps/FetchNbpRates.ps1
param(
    [Parameter(Mandatory=$true)][string]$SqlInstance,
    [Parameter(Mandatory=$true)][string]$Database,
    [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'

# 1) Pobierz JSON z NBP (tabela A – kursy średnie)
$uri = 'https://api.nbp.pl/api/exchangerates/tables/A?format=json'
$response = Invoke-RestMethod -Method GET -Uri $uri -TimeoutSec $TimeoutSeconds

# 2) Serializuj z sensowną głębokością
$json = $response | ConvertTo-Json -Depth 6

# 3) Wywołaj procedurę T-SQL z parametrem @json (NVARCHAR(MAX))
$cs = "Server=$SqlInstance;Database=$Database;Integrated Security=SSPI;TrustServerCertificate=True;"

Add-Type -AssemblyName System.Data
$conn = New-Object System.Data.SqlClient.SqlConnection $cs
$cmd = $conn.CreateCommand()
$cmd.CommandTimeout = $TimeoutSeconds
$cmd.CommandText = 'EXEC dbo.usp_UpsertNbpRatesFromJson @json = @p_json;'
$param = $cmd.Parameters.Add('@p_json',[System.Data.SqlDbType]::NVarChar,-1)
$param.Value = $json

$conn.Open()
try {
    $cmd.ExecuteNonQuery() | Out-Null
    Write-Host "NBP exchange rates ingested successfully."
}
finally {
    $conn.Close()
}
