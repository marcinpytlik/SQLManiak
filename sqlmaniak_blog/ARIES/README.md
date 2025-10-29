# Walec ARIES – Demo SQL Servera (Write-Ahead Logging & Recovery)

Kompletne **demo ARIES / WAL** dla SQL Server 2022.

## ✅ Wymagania
- SQL Server 2019/2022 (Developer/Enterprise)
- `sqlcmd` (ODBC Driver 18+)
- VS Code lub PowerShell
- (opcjonalnie) Grafana + Telegraf (input `sqlserver`) + InfluxDB

## 📦 Zawartość
- `sql/00-create-db.sql` – baza testowa `ARIES_Demo`
- `sql/01-transaction-demo.sql` – zapis i rollback (fn_dblog)
- `sql/02-checkpoint-demo.sql` – checkpoint + restart symulacja
- `sql/03-recovery-sim.sql` – pokazanie faz ARIES w logu
- `sql/dmv/*.sql` – analiza logu i recovery statusu
- `.vscode/tasks.json` – taski pod Windows/VS Code
- `scripts/Run-Demo.ps1` – orkiestrator całego demo
- `grafana/aries-log-usage.json` – dashboard do log usage (%)
- `docs/Walec-ARIES/walec-aries.md` – wpis na blog

## ▶️ Start (PowerShell)
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$env:MSSQL_SERVER="localhost"
$env:MSSQL_USER="sa"
$env:MSSQL_PASS="YourStrong!Passw0rd"
.\scripts\Run-Demo.ps1
```

## 📊 Co zobaczysz
- wpisy `LOP_BEGIN_XACT`, `LOP_INSERT_ROWS`, `LOP_COMMIT_XACT`
- checkpoint w logu (`LOP_BEGIN_CKPT` / `LOP_END_CKPT`)
- aktywne transakcje w `sys.dm_tran_active_transactions`
- użycie logu w `sys.dm_db_log_space_usage` i Grafanie

© 2025 SQLManiak — demo edukacyjne.
