
# Checklist – Nowa instancja SQL 2022 FCI na gMSA (WS2022)

## Etap AD
- [ ] KDS istnieje (`Get-KdsRootKey` lub `Add-KdsRootKey -EffectiveTime ...`)
- [ ] Grupa hostów utworzona (`GRP_SQL_FCI01_GMSA_Hosts`) i zawiera wszystkie węzły
- [ ] gMSA utworzone (`sqlsvc_fci01$`)

## Etap węzły
- [ ] RSAT-AD-PowerShell zainstalowany
- [ ] `Install-ADServiceAccount sqlsvc_fci01` OK, `Test-ADServiceAccount` = True
- [ ] Uprawnienia NTFS/SMB (DATA/LOG/BACKUP)

## Instalacja SQL FCI
- [ ] Engine/Agent ustawione na `DOMAIN\sqlsvc_fci01$` (hasło puste)
- [ ] Instalacja zakończona bez błędów

## Po instalacji
- [ ] SPN dla VNN (`MSSQLSvc/VNN_FQDN` i `MSSQLSvc/VNN_FQDN:1433`) przypisany do gMSA
- [ ] (opcjonalnie) SPN dla AG Listener
- [ ] `auth_scheme` = KERBEROS
- [ ] Failover test → usługa wstaje na drugim węźle
