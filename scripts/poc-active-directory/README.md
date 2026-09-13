# POC Active Directory bootstrap

Wspólny bootstrap kont domenowych dla proof-of-conceptów w labie `sqllab.local`.

## Co robi skrypt

`Initialize-POCActiveDirectory.ps1`:

- tworzy `OU=POC` w katalogu domeny, jeśli OU jeszcze nie istnieje,
- domyślnie tworzy konto `SQLLAB\poc-ssis-app`,
- pobiera hasło interaktywnie jako `SecureString`,
- nie zapisuje hasła w repo,
- włącza konto,
- nie dodaje konta do żadnych dodatkowych grup,
- ustawia `AccountNotDelegated = True`,
- ustawia `TrustedForDelegation = False`,
- ustawia `TrustedToAuthForDelegation = False`,
- wyświetla stan końcowy do weryfikacji,
- można go uruchamiać wielokrotnie.

## Wymagania

- uruchomienie na komputerze z modułem `ActiveDirectory` (RSAT lub kontroler domeny),
- konto wykonujące skrypt musi mieć prawo do tworzenia OU i użytkowników w domenie,
- PowerShell 5.1 lub PowerShell 7 z dostępnym modułem AD.

## POC SSIS secure export

Domyślne uruchomienie:

```powershell
.\Initialize-POCActiveDirectory.ps1
```

Skrypt poprosi o hasło dla:

```text
SQLLAB\poc-ssis-app
```

Wersja jawna z parametrami:

```powershell
.\Initialize-POCActiveDirectory.ps1 `
    -DomainDnsName 'sqllab.local' `
    -OuName 'POC' `
    -SamAccountName 'poc-ssis-app' `
    -DisplayName 'POC SSIS Application Account'
```

Jeżeli w labie świadomie chcesz wyłączyć wygasanie hasła:

```powershell
.\Initialize-POCActiveDirectory.ps1 -PasswordNeverExpires
```

## Kolejne POC

Ten sam skrypt można wykorzystać do kolejnych kont, np.:

```powershell
.\Initialize-POCActiveDirectory.ps1 `
    -SamAccountName 'poc-cdc-app' `
    -DisplayName 'POC CDC Application Account'
```

```powershell
.\Initialize-POCActiveDirectory.ps1 `
    -SamAccountName 'poc-debezium' `
    -DisplayName 'POC Debezium Account'
```

## Oczekiwany stan bezpieczeństwa

```text
AccountNotDelegated        = True
TrustedForDelegation       = False
TrustedToAuthForDelegation = False
```

Dzięki temu konto POC nie może być używane jako konto delegowane dalej do innych usług.
