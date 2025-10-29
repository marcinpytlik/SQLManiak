# TempDB – Laboratorium SQL Servera (Demo)

Kompletne **demo TempDB** pod Windows + VS Code (SQL Server 2022/2019).

## ✅ Wymagania
- SQL Server 2019/2022 (Developer/Enterprise)
- `sqlcmd` (ODBC Driver 18+)
- VS Code (preferowane)
- (Opcjonalnie) Grafana + Telegraf (`sqlserver` input) + InfluxDB

## 📦 Zawartość
- `sql/00-inspect-tempdb.sql` – inwentaryzacja: pliki, rozmiary, growth, usage
- `sql/01-generate-pressure.sql` – kontrolowany stres TempDB (pętle #temp + sort)
- `sql/02-contention-demo.sql` – skrypt do uruchamiania równoległego (wiele sesji)
- `sql/03-best-practices-config.sql` – **szablon** do ustawienia liczby plików, size, growth
- `sql/04-cleanup-demo.sql` – porządki (jeśli tworzono obiekty globalne)
- `sql/dmv/*.sql` – gotowe DMV (IO, usage, waits PAGELATCH, version store)
- `.vscode/tasks.json` – taski pod Windows/VS Code
- `scripts/Run-Demo.ps1` – orkiestracja demo (inspekcja → presja → inspekcja)
- `grafana/tempdb-overview.json` – prosty dashboard (InfluxQL)
- `docs/TempDB-Laboratorium/tempdb-post.md` – wpis na blog (Hugo)

## 🔌 Połączenie (zmienne)
```powershell
$env:MSSQL_SERVER="localhost"
$env:MSSQL_USER="sa"
$env:MSSQL_PASS="YourStrong!Passw0rd"
```

## ▶️ Szybki start (VS Code)
1. Otwórz folder w VS Code.
2. Ustaw zmienne środowiskowe jak powyżej.
3. Odpal taski:
   - `00 – Inspect TempDB`
   - `01 – Generate Pressure`
   - `00 – Inspect TempDB` (ponownie)
   - `DMV – IO Stats` / `DMV – Usage` / `DMV – PAGELATCH`

## ⚠️ Uwaga
- Skrypt `03-best-practices-config.sql` to **szablon** – wymaga świadomej edycji (prod vs dev).
- `02-contention-demo.sql` pokaże efekt dopiero przy **wielu równoległych sesjach** (użyj `-Parallel` w PS).

© 2025 SQLManiak — demo edukacyjne.
