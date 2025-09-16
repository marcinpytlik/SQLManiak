# 🗂️ Rejestr Windows – klucze SQL Server 2022

SQL Server zapisuje konfigurację instancji i usług w rejestrze Windows.  
Ścieżki różnią się w zależności od wersji (`MSSQL16` = SQL Server 2022) i nazwy instancji (`MSSQLSERVER` = instancja domyślna).

---

## 1. Główny katalog SQL Server

```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server
```

- **Setup** – informacje instalacyjne (wersja, ścieżki).  
- **Instance Names** – lista instancji i mapowanie na ID (`MSSQL16.MSSQLSERVER`).  
- **InstalledInstances** – spis wszystkich zainstalowanych instancji.  

---

## 2. Instancja SQL Server (Database Engine)

```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER
```

> Dla instancji nazwanej np. `SQLDEV`:  
> `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.SQLDEV`

- **MSSQLServer\Parameters**  
  - parametry startowe (`-d`, `-l`, `-e` → ścieżki do master.mdf, mastlog.ldf, ERRORLOG).  
- **MSSQLServer\SuperSocketNetLib**  
  - protokoły sieciowe (TCP, Named Pipes, Shared Memory), porty, adresy.  
- **MSSQLServer\Replication**  
  - ustawienia replikacji.  
- **SQLServerAgent**  
  - konfiguracja SQL Agent (historia jobów, logi, parametry).  

---

## 3. Klucz Services

```
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\
```

- **MSSQLSERVER** – konfiguracja usługi Database Engine (dla default instance).  
- **MSSQL$SQLDEV** – dla instancji nazwanej.  
- **SQLAgent$SQLDEV**, **SQLBrowser**, **MsDtsServer150** (SSIS), itp.  
- Zawiera typ startu (Automatic, Manual, Disabled), ścieżkę do binarek (`sqlservr.exe`).

---

## 4. SQL Server Network Configuration

```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\{InstanceID}\MSSQLServer\SuperSocketNetLib
```

- **TCP** – porty, adresy IP, dynamic/static port.  
- **Np** – Named Pipes (włączone/wyłączone).  
- **Sm** – Shared Memory (zwykle zawsze włączone).  

---

## 5. Klucz Setup Bootstrap

```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\160\Tools\Setup
```

- Dane instalatora i aktualizacji.  
- Numer buildu, informacje o CU/SP.  
- Ścieżki do `Setup Bootstrap\Log`.  

---

## 6. Rejestr 32-bit (WOW6432Node)

Na systemach 64-bit część kluczy duplikuje się:  

```
HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server
```

Dotyczy narzędzi 32-bit (np. stary ODBC).

---

## 7. SQL Server Client (natywne klienty)

```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSSQLServer\Client
```

- Konfiguracja aliasów (`Alias`) – zamiana nazw serwerów.  
- Globalne ustawienia klienta (timeout, netlib).

---

## 8. Registry a bezpieczeństwo

- Hasła loginów i klucze szyfrowania **nie są w rejestrze** – trzymane w DPAPI w `ProgramData\Microsoft\Crypto`.  
- Rejestr służy głównie do ścieżek, protokołów, konfiguracji usług.  
- Zmiany w rejestrze bezpośrednio są **ryzykowne** – używaj raczej SQL Server Configuration Manager.  

---

# 🔎 Podsumowanie – najważniejsze lokalizacje

| Klucz rejestru                                                                 | Zawartość                                  |
|--------------------------------------------------------------------------------|--------------------------------------------|
| `HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL`          | lista instancji                             |
| `HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\Parameters` | pliki master.mdf, log, errorlog             |
| `HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\SuperSocketNetLib` | protokoły sieciowe, porty                 |
| `HKLM\SYSTEM\CurrentControlSet\Services\MSSQLSERVER`                        | usługa SQL Server (Engine)                  |
| `HKLM\SYSTEM\CurrentControlSet\Services\SQLAgent$<instancja>`               | usługa SQL Agent                            |
| `HKLM\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo`                     | aliasy klienta                              |
| `HKLM\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server`                  | ustawienia dla narzędzi 32-bit              |
| `HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\160\Tools\Setup`            | dane instalacji/aktualizacji                |

---

📌 **Tip:**  
Rejestr SQL Server przydaje się np. gdy:  
- nie możesz uruchomić instancji i musisz sprawdzić parametry startowe,  
- szukasz portów TCP po dynamicznej konfiguracji,  
- diagnozujesz problemy z aliasami klienta.  
W praktyce jednak zawsze preferuj **Configuration Manager** zamiast edycji rejestru ręcznie.

---

_ostatnia aktualizacja: 2025-09-16_
