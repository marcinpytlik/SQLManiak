
#use remoting to run the script on the DC
CD $PSScriptRoot
Invoke-Command -FilePath .\create_ad_users.ps1 -ComputerName MIA-DC
