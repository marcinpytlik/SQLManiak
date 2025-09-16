# ⚙️ SQL Server 2022 – Metody instalacji

---

## 🔹 1. Instalacja na Windows Server (GUI)

### Opis
- Klasyczny **SQL Server Setup Wizard** (setup.exe).  
- Wybór roli, instancji (Default/Named), komponentów (Database Engine, SSAS, SSRS, Machine Learning).  
- Najłatwiejsza metoda dla początkujących i środowisk demo.

### Zastosowanie
- Środowiska graficzne (Windows Server z GUI).  
- Kiedy DBA chce ręcznie przejść przez konfigurację.

### Komenda startowa
```powershell
setup.exe
```

---

## 🔹 2. Instalacja na Windows Server Core (cmd/PowerShell)

### Opis
- Bez GUI – instalacja w trybie **command line**.  
- Używa `setup.exe` z parametrami lub pliku `ConfigurationFile.ini`.

### Przykład (parametry CLI)
```powershell
setup.exe /Q /ACTION=Install /FEATURES=SQL /INSTANCENAME=MSSQLSERVER `
/SQLSVCACCOUNT="DOMAIN\sqlsvc" /SQLSVCPASSWORD="P@ssw0rd!" `
/AGTSVCACCOUNT="DOMAIN\sqlagent" /AGTSVCPASSWORD="P@ssw0rd!" `
/SECURITYMODE=SQL /SAPWD="StrongP@ssword!"
```

### Zastosowanie
- Produkcja na Windows Server Core.  
- Automatyzacja (skrypty, CI/CD).  

---

## 🔹 3. Instalacja SQL Server na Linux (Ubuntu)

### Opis
- Od SQL Server 2017 Microsoft wspiera Linux.  
- Instalacja odbywa się przez **pakiety apt** (Debian/Ubuntu).

### Przykład instalacji (Ubuntu 22.04)
```bash
# Import repozytorium Microsoft
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list)"

# Instalacja serwera
sudo apt-get update
sudo apt-get install -y mssql-server

# Konfiguracja
sudo /opt/mssql/bin/mssql-conf setup
```

### Zastosowanie
- Środowiska Linux-first.  
- Integracja z kontenerami, DevOps.

---

## 🔹 4. Instalacja w Docker

### Opis
- Najszybszy sposób na testy/dev.  
- Oficjalny obraz Microsoft na DockerHub (`mcr.microsoft.com/mssql/server`).

### Przykład
```bash
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=StrongP@ssword!"    -p 1433:1433 --name sql2022    -d mcr.microsoft.com/mssql/server:2022-latest
```

### Zastosowanie
- Dev/test/lab.  
- CI/CD pipelines.  
- Izolowane środowiska wielu instancji.

---

## 🔎 Podsumowanie metod instalacji

| Platforma        | Metoda           | Kiedy używać |
|------------------|-----------------|--------------|
| Windows (GUI)    | Setup Wizard     | Nauka, demo, małe środowiska |
| Windows (Core)   | CLI/ini          | Produkcja, automatyzacja |
| Linux (Ubuntu)   | apt/yum + mssql-conf | Produkcja Linux, integracja DevOps |
| Docker           | Kontener         | Dev/test, CI/CD, szybkie laby |

---

## 📌 Rekomendacje
- **Lab / szybkie testy** → Docker.  
- **Środowiska produkcyjne Windows** → Core + skrypty instalacyjne.  
- **Środowiska Linux** → Ubuntu/RHEL + `mssql-conf`.  
- GUI → raczej tylko dla nauki i POC.

---

_ostatnia aktualizacja: 2025-09-16_
