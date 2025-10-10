<# 50-AX-BI-Binding.ps1
Powiązanie AX 2012 R3 z SSRS 2016 (C) i redeploy raportów.
Uruchom na serwerze AOS (z AX Management Shell).
#>
param(
  [string]$SsrsServer = "C",
  [switch]$RedeployAll = $true
)

# AX Management Shell cmdlets (załadowane przez AX).
Write-Host "Konfiguracja BI endpoint na $SsrsServer ..." -ForegroundColor Cyan

try {
  # Przykładowe cmdlety – mogą się różnić zależnie od CU.
  if ($RedeployAll) {
    Write-Host "Usuwam stare raporty..."
    Get-AXReport -ServerName $SsrsServer | Remove-AXReport -ErrorAction SilentlyContinue
    Write-Host "Publikuję raporty AX... To potrwa."
    Publish-AXReport -ReportName * -ServerName $SsrsServer
  }
  Write-Host "Gotowe."
} catch {
  Write-Error $_
  exit 1
}
