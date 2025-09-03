# SQL Server 2022 – Instalacja i integracja w różnych środowiskach

**Czas trwania:** 2 dni (16 godzin)  
**Wymagania wstępne:** podstawy administracji Windows Server i Linux, podstawy SQL  
**Grupa docelowa:** administratorzy, DevOps, inżynierowie IT  
**Środowisko:** Windows Server GUI / Core, Linux (Ubuntu, RHEL), Docker, Active Directory  

---

## 🧭 Dzień 1 – Instalacja SQL Server 2022

### 1. Wprowadzenie do SQL Server 2022
- Wersje i edycje: Developer, Standard, Enterprise, Express  
- Nowości w SQL Server 2022  
- Scenariusze wdrożenia  

---

### 2. Instalacja na Windows Server (GUI)
- Wymagania systemowe i sprzętowe  
- Konfiguracja systemu: firewall, konta serwisowe, foldery  
- Instalacja przy użyciu instalatora GUI  
- Konfiguracja komponentów: Database Engine, Agent, SSRS  
- Konfiguracja portów TCP/IP, SQL Browser  
🛠️ **Ćwiczenie:** Instalacja SQL Server 2022 na Windows Server z GUI  

---

### 3. Instalacja na Windows Server Core
- Rola Server Core w środowiskach produkcyjnych  
- Instalacja SQL Server przy użyciu `Setup.exe /q`  
- Zdalna administracja: SSMS, RSAT  
- Konfiguracja sieci i zapory  
🛠️ **Ćwiczenie:** Instalacja SQL Server na Windows Server Core zdalnie  

---

### 4. Instalacja SQL Server na Linux
- Obsługiwane dystrybucje: Ubuntu, RHEL, SUSE  
- Instalacja z repozytorium (`apt`, `yum`)  
- Konfiguracja za pomocą `mssql-conf`  
- Zarządzanie usługami (`systemctl`, `journalctl`)  
- Narzędzia CLI: `sqlcmd`, `bcp`  
🛠️ **Ćwiczenie:** Instalacja SQL Server na Ubuntu Server  

---

### 5. Instalacja w kontenerze Docker
- Obrazy SQL Server na Docker Hub  
- Instalacja Docker na Windows/Linux  
- Tworzenie kontenera SQL Server  
- Ustawienia wolumenów, portów, danych trwałych  
- Diagnostyka i logi kontenerów  
🛠️ **Ćwiczenie:** Uruchomienie SQL Server 2022 w kontenerze Docker  

---

## 🧭 Dzień 2 – Integracja i automatyzacja

### 6. Integracja z Active Directory
- Logowanie Windows – zalety i zastosowania  
- Tworzenie kont serwisowych (PowerShell, ADUC)  
- Nadawanie uprawnień w SQL Server (logins, groups)  
- Konfiguracja SPN (Service Principal Name)  
- Delegacja Kerberos dla usług SQL Server  
🛠️ **Ćwiczenie:** Konfiguracja logowania Windows do SQL Server w domenie  

---

### 7. Uwierzytelnianie AD na Linux
- Dołączanie systemu Linux do domeny (`realmd`, `sssd`)  
- Konfiguracja `krb5.conf` i test Kerberos  
- Konfiguracja SQL Server do logowania AD na Linux  
🛠️ **Ćwiczenie:** Logowanie do SQL Server na Linux z kontem domenowym  

---

### 8. Automatyzacja instalacji SQL Server
- Instalacja bezobsługowa z pliku `ConfigurationFile.ini`  
- Automatyzacja przez PowerShell (`Invoke-Sqlcmd`, `dbatools`)  
- Automatyczna instalacja kontenerów  
- Checklisty instalacyjne i testy powdrożeniowe  
🛠️ **Ćwiczenie:** Przygotowanie pełnej, automatycznej instalacji SQL Server  

---

### 9. Zarządzanie wieloma instancjami
- Instancje nazwane vs domyślne  
- Rejestrowanie w SSMS  
- Central Management Server (CMS)  
- Klonowanie konfiguracji i monitorowanie  

---

## 📌 Materiały dodatkowe
- Skrypty PowerShell do instalacji SQL Server  
- Pliki `ConfigurationFile.ini` dla różnych scenariuszy  
- Przykłady kontenerów SQL Server (Linux, Windows)  
- Checklisty i diagramy wdrożeniowe  
- Lista najczęstszych błędów i rozwiązań  

---

## 📜 Licencja
Repozytorium **sqlmaniak**  
Licencja: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)  
Autor: **Marcin (SQLManiak)**
