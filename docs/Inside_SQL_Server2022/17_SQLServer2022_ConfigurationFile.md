# ⚙️ SQL Server 2022 – ConfigurationFile.ini

---

## 📌 Czym jest ConfigurationFile.ini?

- Plik tekstowy, który zawiera **parametry instalacji SQL Server**.  
- Generowany automatycznie przez kreator instalacji (GUI) w katalogu `C:\Program Files\Microsoft SQL Server\...`.  
- Może być później użyty do instalacji w trybie **cichym (silent)**.  
- Dzięki niemu nie trzeba podawać wszystkich parametrów w `setup.exe`.

---

## 📌 Struktura pliku

- Format = `klucz=wartość`.  
- Sekcje pogrupowane według funkcji (Engine, Analysis Services, Reporting Services itd.).  
- Komentarze zaczynają się od `;`.  

Przykład:
```ini
; SQL Server 2022 Configuration File
[OPTIONS]
ACTION="Install"
FEATURES=SQLENGINE
INSTANCENAME="MSSQLSERVER"
SECURITYMODE=SQL
SAPWD="StrongP@ssw0rd!"
SQLSVCACCOUNT="DOMAIN\sqlsvc"
SQLSVCPASSWORD="P@ssword1!"
AGTSVCACCOUNT="DOMAIN\sqlagent"
AGTSVCPASSWORD="P@ssword2!"
TCPENABLED=1
NPENABLED=0
IACCEPTSQLSERVERLICENSETERMS="True"
```

---

## 📌 Najczęstsze parametry

| Parametr              | Opis |
|-----------------------|------|
| **ACTION**            | Typ akcji (`Install`, `Uninstall`, `Upgrade`). |
| **FEATURES**          | Jakie komponenty instalować (np. `SQLENGINE,REPLICATION,FULLTEXT`). |
| **INSTANCENAME**      | Nazwa instancji (`MSSQLSERVER` = domyślna). |
| **SECURITYMODE**      | `SQL` (Mixed Mode) lub pominięcie = Windows Auth only. |
| **SAPWD**             | Hasło dla konta `sa` (wymagane przy Mixed Mode). |
| **SQLSVCACCOUNT**     | Konto usługi Database Engine. |
| **SQLSVCPASSWORD**    | Hasło dla konta usługi. |
| **AGTSVCACCOUNT**     | Konto usługi SQL Agent. |
| **AGTSVCPASSWORD**    | Hasło dla konta SQL Agent. |
| **TCPENABLED**        | `1` = włącz TCP/IP, `0` = wyłącz. |
| **NPENABLED**         | `1` = Named Pipes on, `0` = off. |
| **INSTALLSQLDATADIR** | Katalog dla plików danych. |
| **SQLUSERDBDIR**      | Domyślny katalog dla baz użytkownika (MDF). |
| **SQLUSERDBLOGDIR**   | Domyślny katalog dla logów (LDF). |
| **SQLTEMPDBDIR**      | Katalog dla tempdb. |
| **SQLBACKUPDIR**      | Domyślny katalog dla backupów. |
| **IACCEPTSQLSERVERLICENSETERMS** | Musi być `True` w trybie silent. |

---

## 📌 Instalacja z pliku

```powershell
setup.exe /ConfigurationFile="D:\Config\ConfigurationFile.ini"
```

Możesz też nadpisać parametry w locie:
```powershell
setup.exe /ConfigurationFile="D:\Config\ConfigurationFile.ini" /SAPWD="NoweHaslo123!"
```

---

## 📌 Jak wygenerować ConfigurationFile.ini?

1. Uruchom instalator w trybie GUI.  
2. Skonfiguruj wszystkie opcje.  
3. Na ekranie końcowym instalator zapisze plik `ConfigurationFile.ini` w katalogu:  
   ```
   C:\Program Files\Microsoft SQL Server\150\Setup Bootstrap\Log\<DataTime>\
   ```

---

## 🔎 Podsumowanie

- **ConfigurationFile.ini** = szablon instalacji → powtarzalność i automatyzacja.  
- Najczęściej używane w środowiskach **Windows Server Core** i **CI/CD**.  
- Możesz trzymać różne pliki `.ini` dla różnych scenariuszy (DEV/TEST/PROD).  
- Pozwala na ciche instalacje (`/Q`) bez interakcji z GUI.  

---

_ostatnia aktualizacja: 2025-09-16_
