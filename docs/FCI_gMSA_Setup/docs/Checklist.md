
# Checklist – FCI na dwóch gMSA

## AD
- [ ] KDS istnieje
- [ ] Grupa hostów z węzłami
- [ ] gMSA Engine: utworzone
- [ ] gMSA Agent: utworzone

## Węzły
- [ ] Zainstalowane oba gMSA (`Test-ADServiceAccount` = True)
- [ ] Uprawnienia NTFS/SMB dla gMSA Engine (DATA/LOG/BACKUP)

## Instalacja SQL
- [ ] Engine = `DOMAIN\sqlsvc_fci01$`
- [ ] Agent  = `DOMAIN\sqlagt_fci01$`

## Po instalacji
- [ ] SPN dla VNN przypisany do `sqlsvc_fci01$`
- [ ] (opcjonalnie) SPN dla AG Listener
- [ ] `auth_scheme` = KERBEROS
- [ ] Failover OK
