# Secure Export POC - uruchamianie z DEWELOPER

Cały POC administrujemy ze stacji `DEWELOPER`. Nie ma potrzeby używania Remote Desktop do `SQL64` ani `DC01`.

## 1. Uruchom PowerShell 7 z poświadczeniami SQLLAB

```cmd
runas /netonly /user:SQLLAB\Administrator pwsh.exe
```

Następnie:

```powershell
cd C:\Users\blad\Documents\GitHub\SQLManiak\scripts\ssis-secure-export-poc
```

Sprawdzenie infrastruktury:

```powershell
Test-WSMan sql64.sqllab.local
Test-WSMan dc01.sqllab.local
Test-NetConnection sql64.sqllab.local -Port 1433
Resolve-DnsName sql64.sqllab.local
Resolve-DnsName dc01.sqllab.local
```

## 2. Skrypty PowerShell

### 07-create-export-account.ps1

Uruchamiany lokalnie na `DEWELOPER`. Skrypt sam wykonuje operacje AD na `DC01` przez WinRM.

```powershell
.\07-create-export-account.ps1
```

Nie uruchamiaj go przez `Invoke-Command -FilePath`.

### 08-create-test-share.ps1

Uruchamiany lokalnie na `DEWELOPER`. Skrypt konfiguruje folder, SMB i NTFS na `DC01` przez WinRM.

```powershell
.\08-create-test-share.ps1
```

Test bez zmian:

```powershell
.\08-create-test-share.ps1 -WhatIf
```

### 09-test-share-access.ps1

Uruchamiany lokalnie na `DEWELOPER`. Domyślnie testuje:

```text
\\dc01.sqllab.local\SSISLab$
```

jako:

```text
SQLLAB\poc-ssis-export
```

```powershell
.\09-test-share-access.ps1
```

Skrypt poprosi o hasło konta eksportowego i wykona test create/read/delete.

### 10-create-sql-agent-credential.ps1

Uruchamiany lokalnie na `DEWELOPER`. Łączy się bezpośrednio do:

```text
sql64.sqllab.local,1433
```

przy użyciu Windows Integrated Authentication odziedziczonego z `runas /netonly`.

```powershell
.\10-create-sql-agent-credential.ps1
```

Skrypt poprosi wyłącznie o hasło konta `SQLLAB\poc-ssis-export`, które jest zapisywane jako SECRET SQL Server Credential.

### 17-stage5-worker.ps1

To jest wyjątek: **worker runtime musi działać na SQL64 pod SQL Agent Proxy**. Nie uruchamiamy workera interaktywnie na DEWELOPER.

Z DEWELOPER wdrażamy aktualną wersję workera na SQL64:

```powershell
.\17-stage5-worker.ps1 `
    -DeployToSql64 `
    -RemoteWorkerPath 'C:\SSIS\POC\Stage5Worker.ps1'
```

Plik trafia na:

```text
SQL64:C:\SSIS\POC\Stage5Worker.ps1
```

To jest ścieżka używana przez `18-create-stage5-job.sql`.

Po wdrożeniu worker jest uruchamiany przez SQL Agent, nie przez RDP i nie bezpośrednio z DEWELOPER.

### 20-cleanup-poc.ps1

Uruchamiany **bezpośrednio lokalnie na DEWELOPER**. Skrypt jest orchestrator'em i wykonuje osobne połączenia:

```text
DEWELOPER -> SQL64
DEWELOPER -> DC01
```

Nie uruchamiaj:

```powershell
Invoke-Command -ComputerName sql64.sqllab.local -FilePath .\20-cleanup-poc.ps1
```

Najpierw:

```powershell
.\20-cleanup-poc.ps1 -WhatIf
```

Cleanup:

```powershell
.\20-cleanup-poc.ps1 -Force
```

Skrypt jest idempotentny i może być uruchamiany wielokrotnie.

## 3. Model końcowy

```text
                         DEWELOPER
                    PowerShell 7 / VS Code
                           |
             +-------------+-------------+
             |                           |
          WinRM                         WinRM
             |                           |
             v                           v
           SQL64                       DC01
     SQL / Agent / worker        AD / SMB / NTFS
             |
             | SQL Agent Proxy
             v
   C:\SSIS\POC\Stage5Worker.ps1
             |
             v
   \\dc01.sqllab.local\SSISLab$
```

## 4. Zasada

Wszystkie czynności administracyjne inicjujemy z `DEWELOPER`.

Wyjątek stanowi `17-stage5-worker.ps1`: jest wdrażany z DEWELOPER, ale runtime wykonuje się lokalnie na SQL64 pod dedykowanym SQL Agent Proxy. Dzięki temu zachowujemy poprawny model bezpieczeństwa POC i nie tworzymy problemu double-hop.
