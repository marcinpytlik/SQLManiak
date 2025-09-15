# 📘 Instalacja SQL Server Reporting Services 2016 z bazami na SQL Server 2019 FCI (`SQLSRVCluster`)

## 1. Przygotowanie środowiska
- [ ] Masz **klaster SQL Server 2019 FCI (Active/Passive)** z wirtualną nazwą instancji: `SQLSRVCluster`.
- [ ] Masz **osobny serwer dla SSRS 2016 (Native Mode)**.
- [ ] Konto usługi SSRS: `DOMAIN\svc_SSRS`.
- [ ] Twoje konto administracyjne ma prawa `sysadmin` na `SQLSRVCluster`.

---

## 2. Uprawnienia w SQL Server FCI
Zaloguj się do `SQLSRVCluster` i dodaj konto usługi SSRS:

```sql
CREATE LOGIN [DOMAIN\svc_SSRS] FROM WINDOWS;
ALTER SERVER ROLE sysadmin ADD MEMBER [DOMAIN\svc_SSRS];
```

> `sysadmin` ułatwia konfigurację. Po zakończeniu możesz ograniczyć uprawnienia do `db_owner` na bazach ReportServer i ReportServerTempDB.

---

## 3. Instalacja SSRS 2016
Na dedykowanym serwerze SSRS:

- [ ] Pobierz instalator **SQL Server 2016 Reporting Services** (osobny EXE).  
- [ ] Zainstaluj w trybie **Native Mode**.  
- [ ] Wskaż konto usługi: `DOMAIN\svc_SSRS`.  
- [ ] Instalację wykonaj **bez konfiguracji** (tylko pliki binarne).

---

## 4. Konfiguracja w Reporting Services Configuration Manager

### 4.1 Service Account
- [ ] Ustaw `DOMAIN\svc_SSRS`.  
- [ ] Zastosuj zmiany i uruchom ponownie usługę.

### 4.2 Web Service URL
- [ ] Skonfiguruj np. `http://SSRS01/ReportServer`.

### 4.3 Database (kluczowy krok)
1. [ ] Kliknij **Change Database** → *Create a new report server database*.  
2. [ ] **Server Name:** wpisz `SQLSRVCluster`.  
3. [ ] **Authentication:** wybierz *Windows Authentication*.  
   - Używane jest **Twoje konto administracyjne** (sysadmin) do utworzenia baz.  
4. [ ] **Database Name:** `ReportServer` (utworzy też `ReportServerTempDB`).  
5. [ ] **Credentials for SSRS:**  
   - Authentication: Windows Credentials  
   - User name: `DOMAIN\svc_SSRS`  
   - Password: hasło konta usługi  
6. [ ] Kliknij **Next** → **Finish**.  

> Efekt: bazy `ReportServer` i `ReportServerTempDB` powstają na FCI `SQLSRVCluster`, a konto `DOMAIN\svc_SSRS` dostaje `db_owner`.

### 4.4 Web Portal URL
- [ ] Skonfiguruj np. `http://SSRS01/Reports`.

### 4.5 Encryption Keys
- [ ] Wykonaj backup klucza szyfrowania:  
  ```bash
  rskeymgmt -e -f C:\Backup\SSRS_Key.snk -p StrongPassword
  ```  
- [ ] Przechowuj plik w bezpiecznym miejscu.

---

## 5. Testy działania
- [ ] Otwórz portal SSRS: `http://SSRS01/Reports`.  
- [ ] Wgraj testowy raport.  
- [ ] Wykonaj **failover FCI** na drugi węzeł.  
- [ ] Zweryfikuj, że raporty nadal działają.  
- [ ] W SSMS sprawdź, że połączenia do `ReportServer` są wykonywane przez `DOMAIN\svc_SSRS`.

---

## 6. (Opcjonalnie) HA warstwy SSRS
- [ ] Postaw drugi serwer SSRS 2016.  
- [ ] W Configuration Manager wskaż tę samą bazę na `SQLSRVCluster`.  
- [ ] Przywróć klucz szyfrowania.  
- [ ] Postaw oba serwery za load balancerem → masz farmę SSRS (scale-out).

---

## 7. Typowe problemy i rozwiązania
- **Podłączenie do fizycznego węzła** zamiast do `SQLSRVCluster` → po failoverze SSRS traci dostęp.  
- **Brak SPN** → problemy z Kerberosem. Zarejestruj na koncie usługi SQL:  
  ```bash
  setspn -S MSSQLSvc/SQLSRVCluster:1433 DOMAIN\SQLServiceAccount
  setspn -S MSSQLSvc/SQLSRVCluster.domain.local:1433 DOMAIN\SQLServiceAccount
  ```
- **Brak backupu klucza szyfrowania** → brak możliwości odszyfrowania subskrypcji/poświadczeń po reinstalacji.

---

## 8. Diagram architektury

```
               +----------------------+
               |   Użytkownik SSRS    |
               | (przeglądarka/klient)|
               +----------+-----------+
                          |
                          v
               +----------------------+
               |      SSRS 2016       |
               |    (SSRS01 server)   |
               +----------+-----------+
                          |
                          v
        +--------------------------------------+
        |        SQL Server 2019 FCI           |
        |  Virtual Name: SQLSRVCluster         |
        +-----------------+--------------------+
                          |
          +---------------+---------------+
          |                               |
+---------------------+        +---------------------+
|   Node1 (Active)    |        |   Node2 (Passive)   |
+---------------------+        +---------------------+

```

---

## ✅ Podsumowanie
- Bazy SSRS (`ReportServer`, `ReportServerTempDB`) działają na FCI `SQLSRVCluster`.  
- SSRS 2016 korzysta z konta `DOMAIN\svc_SSRS` do pracy.  
- Całość jest odporna na failover FCI.  
- Backup klucza szyfrowania to obowiązkowy krok bezpieczeństwa.  
