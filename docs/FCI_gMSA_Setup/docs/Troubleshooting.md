
# Troubleshooting (skrót)

- NTLM zamiast Kerberos → brak/niewłaściwy SPN; klient używa IP; DNS/FQDN niespójny.
- Runner nie może dodać SPN → brak delegacji "Write SPN" na gMSA silnika.
- gMSA test = False → ponownie `Install-ADServiceAccount`, sprawdź członkostwo w grupie hostów.
- Agent nie startuje → upewnij się, że konto to `sqlagt_fci01$` (gMSA) i ma dostęp do ścieżek jobów/backupów jeśli potrzebne.
