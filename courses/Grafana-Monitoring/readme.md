# Monitoring i wizualizacja danych z wykorzystaniem Grafany – Windows i SQL Server

**Czas trwania:** 3 dni (24 godziny)  
**Wymagania wstępne:** podstawy administracji Windows Server i SQL Server  
**Grupa docelowa:** administratorzy systemów, DevOps, inżynierowie danych  
**Środowisko:** Windows Server, Grafana, InfluxDB OSS 2.x, Telegraf  

---

## 🧭 Dzień 1 – Grafana i zbieranie danych

### Moduł 1: Wprowadzenie
- Architektura Grafany i komponenty (InfluxDB, Prometheus, Telegraf)  
- Typy źródeł danych: czasowe, logi, SQL  
- Kluczowe metryki: system, SQL Server  

---

### Moduł 2: Instalacja i konfiguracja
- Instalacja Grafany (Windows Server)  
- Instalacja InfluxDB OSS 2.x  
- Instalacja i konfiguracja Telegraf na Windows  
🛠️ **Ćwiczenia:**  
- Instalacja Grafany jako usługi Windows  
- Połączenie Grafany z InfluxDB  
- Konfiguracja Telegraf do zbierania metryk systemowych  

---

### Moduł 3: Monitoring Windows Server
- CPU, RAM, dyski, procesy, sieć  
- Konfiguracja `inputs.win_perf_counters` w Telegrafie  
🛠️ **Ćwiczenia:**  
- Dodanie liczników wydajności Windows do Telegraf  
- Tworzenie dashboardu CPU i RAM  

---

## 🧭 Dzień 2 – Monitoring SQL Server

### Moduł 4: Monitoring SQL Server
- Telegraf plugin `inputs.sqlserver`  
- Kluczowe metryki: deadlocki, sesje, I/O, wait stats  
🛠️ **Ćwiczenia:**  
- Konfiguracja Telegraf z użytkownikiem SQL Server  
- Dashboard SQL Server: sesje, zapytania, obciążenie  

---

### Moduł 5: Dashboardy i panele
- Zmienne, filtry, eksploracja danych  
- Eksport/import dashboardów  
🛠️ **Ćwiczenia:**  
- Dashboard z dynamicznymi zmiennymi  
- Widok łączony: CPU + SQL  

---

## 🧭 Dzień 3 – Alerty, automatyzacja, integracje

### Moduł 6: Alerting
- Alerty w Grafanie 10+: reguły, progi  
- Notyfikacje: e-mail, webhook, Teams  
🛠️ **Ćwiczenia:**  
- Alert wysokiego CPU w Windows  
- Powiadomienie e-mail  

---

### Moduł 7: Provisioning i automatyzacja
- Dashboard-as-code: JSON, API REST  
- Provisioning źródeł danych i dashboardów  
🛠️ **Ćwiczenia:**  
- Import dashboardu przez API lub plik JSON  
- Provisioning dashboardów do folderu  

---

### Moduł 8: Pluginy i bezpieczeństwo
- Instalacja pluginów (Pie Chart, Status Panel)  
- RBAC, uprawnienia, audyt logowania  
🛠️ **Ćwiczenia:**  
- Instalacja i konfiguracja pluginu  
- Ustawienia ról i dostępów  

---

## 📌 Materiały dodatkowe
- Checklisty instalacyjne  
- Konfiguracje Telegraf (`telegraf.conf`)  
- Dashboardy JSON dla SQL Server i Windows  
- Dokumentacja i źródła  

---

## 📜 Licencja
Repozytorium **sqlmaniak**  
Licencja: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)  
Autor: **Marcin (SQLManiak)**
