param(
  [string]$Server = "localhost",
  [ValidateSet("Windows","SQL")] [string]$Auth = "Windows",
  [string]$User = "",
  [string]$Password = "",
  [string]$DbName = "TwojaBaza",
  [string]$AdGroupLab = "DOMENA\RG_LAB_TwojaBaza",
  [string]$AdGroupProd = "DOMENA\RG_PROD_TwojaBaza",
  [string]$AppNameLabPattern = "%LAB%",
  [string]$AppNameProdPattern = "%PROD%"
)

$authArgs = if($Auth -eq "SQL"){ @("-U",$User,"-P",$Password) } else { @("-E") }

Write-Host "== 00_prereqs ==" -ForegroundColor Cyan
sqlcmd -S $Server @authArgs -d master -b -i "scripts/00_prereqs.sql"
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }

Write-Host "== 10_presets_ab ==" -ForegroundColor Cyan
sqlcmd -S $Server @authArgs -d master -b -i "scripts/10_presets_ab.sql" `
  -v DbName="$DbName" AdGroupLab="$AdGroupLab" AdGroupProd="$AdGroupProd" `
     AppNameLabPattern="$AppNameLabPattern" AppNameProdPattern="$AppNameProdPattern"

Write-Host "Done. Use scripts/20_verify.sql to verify." -ForegroundColor Green
