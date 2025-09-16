# Odinstalowanie SQL Server bez instalatora

Możesz odinstalować SQL Server bez posiadania instalatora `.exe` – system Windows ma wbudowany deinstalator dla zainstalowanych produktów.

---

## Krok po kroku

### 1. Panel sterowania
- Otwórz **Panel sterowania → Programy i funkcje**.  
- Znajdź wpisy takie jak:
  - `Microsoft SQL Server 2016 (64-bit)`
  - `Microsoft SQL Server 2016 Setup (English)`
  - `Microsoft SQL Server Management Studio` (jeśli było instalowane osobno).

### 2. Odinstalowanie instancji
- Kliknij **Microsoft SQL Server 2016 (64-bit)** → *Odinstaluj/Zmień*.  
- Uruchomi się **SQL Server Setup**.  
- Wybierz opcję **Remove**.  
- Zaznacz instancję do usunięcia (np. `MSSQLSERVER`, `SQL2022DEV`).  
- Możesz usunąć tylko wybrane funkcje (Database Engine, Reporting Services, Full-Text, Client Tools) albo całość.

### 3. Usunięcie pozostałych komponentów
Po usunięciu instancji wciąż pozostają dodatkowe składniki, które warto odinstalować ręcznie:
- SQL Server Browser  
- SQL Server VSS Writer  
- Microsoft SQL Server Setup Support Files  
- Microsoft SQL Server Native Client  

### 4. Usunięcie katalogów (opcjonalne)
Po backupie danych usuń pozostałe foldery:
- `C:\Program Files\Microsoft SQL Server\`  
- `C:\Program Files (x86)\Microsoft SQL Server\`  
- `C:\Program Files\Microsoft SQL Server Management Studio\`  
- `C:\ProgramData\Microsoft\SQL Server\` (ukryty katalog).  

### 5. Rejestr (opcjonalne sprzątanie)
- Klucz rejestru:  
- Usuwaj ostrożnie, szczególnie jeśli planujesz instalację innych wersji SQL Server.

---

## Ważne uwagi
- Jeśli SQL Server działał w klastrze FCI/AG, najpierw usuń instancję z klastra.  
- Zrób **kopię baz danych** (pliki `.mdf`, `.ldf`, `.bak`) przed odinstalowaniem – katalog `DATA` jest usuwany razem z instancją.  

---

## Automatyzacja (PowerShell)
Możliwe jest odinstalowanie SQL Server w trybie cichym przez PowerShell, np. w środowisku labowym.  
(zobacz remove_sql2016.ps1). 
# Jak użyć
- Próba na sucho wyświetla to zostanie wykonane
- .\Uninstall-SqlInstance.ps1 -InstanceName "MSSQLSERVER" -WhatIf
- Realna deinstalacja całej instancji
- .\Uninstall-SqlInstance.ps1 -InstanceName "MSSQLSERVER"
- Deinstalacja + próba usunięcia współdzielonych komponentów
- .\Uninstall-SqlInstance.ps1 -InstanceName "SQL2016DEV" -RemoveShared
- Więcej logów (pliki w C:\Temp\SqlUninstall)
- .\Uninstall-SqlInstance.ps1 -InstanceName "SQL2016DEV" -VerboseLog

