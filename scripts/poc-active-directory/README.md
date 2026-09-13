# POC Active Directory bootstrap

Wspólny bootstrap kont domenowych dla proof-of-conceptów w labie `sqllab.local`.

## Model uruchamiania

Skrypt uruchamiamy lokalnie na stacji `DEWELOPER`.

Nie wymaga lokalnego modułu `ActiveDirectory`. Łączy się przez WinRM bezpośrednio do `dc01.sqllab.local`, a moduł AD jest ładowany dopiero w sesji zdalnej na kontrolerze domeny.

Zalecane uruchomienie PowerShella:

```cmd
runas /netonly /user:SQLLAB\Administrator pwsh.exe
```

Architektura:

```text
DEWELOPER -> WinRM -> DC01 -> Active Directory
```

Nie używamy pośredniego połączenia przez SQL64, dzięki czemu unikamy problemu WinRM second-hop.

## Co robi skrypt

`Initialize-POCActiveDirectory.ps1`:

- testuje WinRM do `dc01.sqllab.local`,
- tworzy `OU=POC`, jeśli OU jeszcze nie istnieje,
- domyślnie tworzy konto `SQLLAB\poc-ssis-app`,
- pobiera hasło interaktywnie jako `SecureString`,
- nie zapisuje hasła w repo,
- włącza konto,
- nie dodaje konta do żadnych dodatkowych grup,
- ustawia `AccountNotDelegated = True`,
- ustawia `TrustedForDelegation = False`,
- ustawia `TrustedToAuthForDelegation = False`,
- wyświetla stan końcowy do weryfikacji,
- jest idempotentny i można go uruchamiać wielokrotnie.

## Wymagania

- PowerShell 5.1 lub nowszy na `DEWELOPER`,
- działający WinRM z `DEWELOPER` do `dc01.sqllab.local`,
- konto używane do połączenia sieciowego musi mieć prawo do tworzenia OU i użytkowników w domenie,
- moduł `ActiveDirectory` musi być dostępny na `DC01`.

Test WinRM:

```powershell
Test-WSMan dc01.sqllab.local
```

## POC SSIS secure export

Domyślne uruchomienie z `DEWELOPER`:

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
    -DomainController 'dc01.sqllab.local' `
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
