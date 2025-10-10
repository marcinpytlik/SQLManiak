
# Troubleshooting

## AuthScheme = NTLM zamiast KERBEROS
- Brak SPN lub zły SPN (zła nazwa konta, brak portu przy instancji nazwanej).
- DNS/FQDN niezgodny z tym, czego używa klient.
- Klient łączy się po IP → Kerberos nie zadziała (użyj FQDN VNN).

## Usługa nie startuje po rotacji hasła
- Sprawdź, czy to naprawdę gMSA (nazwa z `$`).
- `Test-ADServiceAccount` na węźle = False → ponownie `Install-ADServiceAccount`.
- Weryfikuj dostęp NTFS/SMB.

## Brak modułu AD na węźle
- `Install-WindowsFeature RSAT-AD-PowerShell` i `Import-Module ActiveDirectory`.
- Alternatywnie uruchom instalację gMSA zdalnie (PowerShell Remoting) z hosta admin.

## SPN „duplicate”
- Usuń duplikat: `setspn -D MSSQLSvc/VNN_FQDN some\account`
- Potem dodaj właściwy do gMSA.
