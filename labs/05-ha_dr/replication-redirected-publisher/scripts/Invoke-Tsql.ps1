param(
  [Parameter(Mandatory)][string]$Server,
  [string]$InputFile,
  [string]$Query,
  [string]$Database = 'master',
  [switch]$UseSqlAuth,
  [string]$User,
  [string]$Password
)
# Wymaga sqlcmd.exe w PATH. Wersja SSMS/SQL Client Tools.
if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
  throw "sqlcmd.exe nie jest w PATH. Zainstaluj klienta SQL lub SSMS."
}
$auth = @()
if ($UseSqlAuth) {
  if (-not $User) { throw "Brak -User dla UseSqlAuth" }
  $auth = @('-U', $User, '-P', $Password)
} else {
  $auth = @('-E')
}

if (-not $InputFile -and -not $Query) {
  throw "Podaj -InputFile albo -Query."
}
$common = @('-S', $Server, '-d', $Database, '-b', '-r1') + $auth

if ($InputFile) {
  Write-Host "===> $Server : $InputFile" -ForegroundColor Cyan
  & sqlcmd @common -i $InputFile
} else {
  $q = $Query.Replace("`n"," ")
  Write-Host "===> $Server : -Q `"$($q.Substring(0,[Math]::Min(80,$q.Length)))...`"" -ForegroundColor Cyan
  & sqlcmd @common -Q $Query
}
if ($LASTEXITCODE -ne 0) {
  throw "sqlcmd zakończył się kodem $LASTEXITCODE na $Server"
}
