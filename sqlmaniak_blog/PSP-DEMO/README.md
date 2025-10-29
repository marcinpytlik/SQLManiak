# Parameter Sensitive Plan (PSP) – Demo (SQL Server 2022)

Ten pakiet zawiera **kompletne demo PSP** pod Windows + VS Code.

## ✅ Wymagania
- SQL Server 2022 (Developer/Enterprise) lokalnie lub zdalnie
- Narzędzie `sqlcmd` (wraz z ODBC Driver 18+)
- VS Code (preferowany)
- (Opcjonalnie) Grafana + Telegraf (plugin `sqlserver`) + InfluxDB

## 📦 Zawartość
- `sql/00-prereq.sql` – tworzy bazę `PSP_Demo`, włącza Query Store
- `sql/01-create-data.sql` – generuje schemat i **mocno skośne dane**
- `sql/02-proc-and-indexes.sql` – tworzy indeksy + procedurę `dbo.GetOrdersByCustomer`
- `sql/03-run-scenarios.sql` – uruchamia scenariusze rozgrzewające PSP
- `sql/dmv/qs-variants.sql` – warianty planów PSP (Query Store)
- `sql/dmv/cached-psp-xml.sql` – wyszukuje PSP w planach XML
- `sql/05-cleanup.sql` – sprzątanie (usuwa bazę)
- `.vscode/tasks.json` – gotowe taski do odpalania skryptów w kolejności
- `scripts/Run-Demo.ps1` – skrypt PowerShell uruchamiający całość
- `grafana/psp-overview.json` – dashboard pod Telegraf->InfluxDB

## 🔌 Połączenie
Domyślnie taski używają zmiennych środowiskowych:

- `MSSQL_SERVER` (np. `localhost`)
- `MSSQL_USER` (np. `sa`)
- `MSSQL_PASS` (hasło)

Ustaw w PowerShell:
```powershell
$env:MSSQL_SERVER="localhost"
$env:MSSQL_USER="sa"
$env:MSSQL_PASS="YourStrong!Passw0rd"
```

## ▶️ Szybki start (VS Code)
1. Otwórz folder w VS Code.
2. `Terminal` → `New Terminal`, ustaw zmienne środowiskowe (jak wyżej).
3. `Ctrl+Shift+P` → „Tasks: Run Task” → wybierz:
   - `00 – Prereq`
   - `01 – Create Data`
   - `02 – Proc & Indexes`
   - `03 – Run Scenarios`
   - (opcjonalnie) uruchom zapytania z `sql/dmv` i podejrzyj **warianty planów**.

## ▶️ Szybki start (PowerShell)
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$env:MSSQL_SERVER="localhost"
$env:MSSQL_USER="sa"
$env:MSSQL_PASS="YourStrong!Passw0rd"
.\scripts\Run-Demo.ps1
```

## 🧪 Co zobaczysz
- Dla tej samej procedury **co najmniej 2 warianty planu** (seek vs scan),
- Flagi PSP w Query Store (`is_parameter_sensitive_plan = 1`),
- W planie XML wpis: `<ParameterSensitivePlan>True</ParameterSensitivePlan>`.

## 🧰 DMV do analizy (skrót)
- `sql/dmv/qs-variants.sql` — lista `query_id` → `plan_id` (warianty)
- `sql/dmv/cached-psp-xml.sql` — wyszukiwanie PSP po treści planu

## 🧹 Sprzątanie
Uruchom `sql/05-cleanup.sql` lub task „05 – Cleanup”.

---

© 2025 SQLManiak — demo edukacyjne.
