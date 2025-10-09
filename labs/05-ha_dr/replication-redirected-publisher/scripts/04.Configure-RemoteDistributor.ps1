param([Parameter(Mandatory)][hashtable]$P)
# Ten krok wymaga edycji sql/02_configure_remote_distributor.sql (są dwie sekcje A i C).
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql\02_configure_remote_distributor.sql' | Tee-Object -Variable sqlfile | Out-Null

Write-Host "===> Upewnij się, że w pliku $sqlfile odkomentujesz sekcje dla C i A zgodnie z instrukcją."
Read-Host "Naciśnij Enter, aby uruchomić NAJPIERW sekcję na C (sp_adddistributor na ServerC)"
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.NewPublisherC -InputFile $sqlfile -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword

Read-Host "Naciśnij Enter, aby uruchomić sekcję na A (sp_adddistpublisher rejestrująca C)"
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.PublisherA -InputFile $sqlfile -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword
