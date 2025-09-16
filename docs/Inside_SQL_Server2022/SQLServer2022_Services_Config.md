# ⚙️ Usługi i pliki konfiguracyjne SQL Server 2022

SQL Server to nie tylko silnik bazy – instaluje zestaw usług systemowych i plików konfiguracyjnych.  
Zrozumienie ich roli pomaga w diagnostyce, automatyzacji i bezpieczeństwie.

---

## 1. Usługi SQL Server

Każda instancja może mieć własne usługi. Wszystkie są widoczne w:

- `services.msc` (Windows Services)  
- SQL Server Configuration Manager (`SQLServerManager16.msc`)  

### Podstawowe usługi

| Usługa                     | Nazwa (default instance) | Nazwa (named instance) | Opis |
|----------------------------|--------------------------|-------------------------|------|
| **SQL Server (Engine)**    | `MSSQLSERVER`           | `MSSQL$SQLDEV`          | Główna usługa bazy danych |
| **SQL Server Agent**       | `SQLSERVERAGENT`        | `SQLAgent$SQLDEV`       | Harmonogram jobów, alerty, operatorzy |
| **SQL Server Browser**     | `SQLBrowser`            | `SQLBrowser`            | Rozgłasza instancje i porty w sieci |
| **SQL Server Launchpad**   | `MSSQLLaunchpad`        | `MSSQLLaunchpad$SQLDEV` | Uruchamia zewnętrzne sesje (R, Python, ML) |
| **SQL Full-text Filter Daemon Launcher** | `MSSQLFDLauncher` | `MSSQLFDLauncher$SQLDEV` | Obsługa indeksów Full-Text |
| **SQL Writer**             | `SQLWriter`             | `SQLWriter`             | Integracja z VSS (backup na poziomie systemu) |

### Dodatkowe komponenty (opcjonalne)

| Usługa                               | Nazwa                  | Opis |
|--------------------------------------|------------------------|------|
| **SQL Server Reporting Services**    | `SQLServerReportingServices` | Raporty SSRS |
| **SQL Server Analysis Services**     | `MSOLAP$SQLDEV`        | Kostki OLAP, modele tablicowe |
| **SQL Server Integration Services**  | `MsDtsServer150`       | Pakiety SSIS |
| **PolyBase Data Movement**           | `Dmsdmsvc`             | PolyBase (rozproszona integracja danych) |
| **PolyBase Engine**                  | `Dmsvc`                | Wykonywanie zapytań PolyBase |
| **Distributed Replay Controller/Client** | `SQLDREPLAYCTRL` / `SQLDREPLAYCLIENT` | Narzędzia do odtwarzania obciążenia |

---

## 2. Konta serwisowe

- Domyślnie każda usługa ma swoje konto wirtualne (`NT Service\MSSQLSERVER`, `NT Service\SQLAgent$SQLDEV`).  
- Zalecane: używać **Managed Service Accounts (gMSA)** w środowisku domenowym.  
- Uprawnienia minimalne: konto engine’a ma dostęp do plików DB, backupów, logów.

---

## 3. Pliki konfiguracyjne SQL Server

### a) Database Engine
- 📂 `...\MSSQL\Binn\sqlservr.exe` – główny binarny proces (nie edytuje się).  
- 📂 Parametry startowe (master, log, errorlog) – w **rejestrze** (`Parameters`).  

### b) Reporting Services
- 📂 `C:\Program Files\Microsoft SQL Server Reporting Services\SSRS\ReportServer\`  
  - `rsreportserver.config` – główna konfiguracja (połączenia, baza ReportServer).  
  - `rssrvpolicy.config` – polityki bezpieczeństwa .NET.  
  - `web.config` – konfiguracja portalu webowego.

### c) Analysis Services
- 📂 `...\MSAS16.<Instance>\OLAP\Config\msmdsrv.ini`  
  - parametry pamięci, ścieżki danych, timeouty.

### d) Integration Services
- 📂 `C:\Program Files\Microsoft SQL Server\150\DTS\Binn\MsDtsSrvr.ini.xml`  
  - konfiguracja serwera SSIS, lista folderów paczek.

### e) PolyBase
- 📂 `...\PolyBase\Config\`  
  - pliki JSON/XML do konfiguracji konektorów i usług Data Movement.

### f) Full-Text Search
- 📂 `...\MSSQL\FTData\`  
  - wewnętrzne pliki indeksów i konfiguracja FTS.

---

## 4. Pliki użytkownika i konfiguracja ścieżek

- **Bazy systemowe**: `...\MSSQL\DATA\`  
- **ERRORLOG, SQLAGENT.OUT**: `...\MSSQL\Log\`  
- **Extended Events**: `...\MSSQL\Log\*.xel`  
- **Backupy**: domyślne ścieżki wskazane w `SERVERPROPERTY('InstanceDefaultBackupPath')`

---

# 🔎 Podsumowanie

- Usługi SQL Server → `services.msc` / Configuration Manager.  
- Pliki konfiguracyjne najczęściej → Reporting Services, Analysis Services, SSIS, PolyBase.  
- Database Engine → praktycznie cała konfiguracja siedzi w **rejestrze** i DMVs, nie w plikach tekstowych.  
- DBA powinien znać miejsca: `rsreportserver.config`, `msmdsrv.ini`, `MsDtsSrvr.ini.xml`, bo czasem **ręczna edycja** jest jedyną opcją.  

---

_ostatnia aktualizacja: 2025-09-16_
