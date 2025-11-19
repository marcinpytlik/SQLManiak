# SQLManiak – Replication Diagnostics (SQL Server)

Pakiet do szybkiego diagnozowania błędów replikacji (Transactional/Merge) oraz podstawowego monitoringu.
Przygotowane pod **Windows + VS Code** (SQL Server 2022 Developer) – tak jak lubisz, marcin 🙂

## 📦 Zawartość
- `sql/` – zapytania śledcze (błędy, historia agentów, zdrowie replikacji)
- `sql/views/Replication_Errors_Dashboard.sql` – widok zbierający najważniejsze błędy z dystrybutora
- `sqlagent/Create-ReplicationErrorEmailJob.sql` – job SQL Agenta wysyłający e-mail z nowymi błędami
- `powershell/Setup-ReplLogs.ps1` – tworzy katalog logów agentów (`C:\ReplLogs`)
- `.vscode/tasks.json` – gotowe taski do uruchamiania zapytań przez `sqlcmd`
- `.snippets/replication.code-snippets` – krótkie snippet’y do T-SQL

## ⚙️ Wymagania
- Windows, VS Code
- Zainstalowany `sqlcmd` (Microsoft ODBC / mssql-tools18) – wersja 18+
- Uprawnienia sysadmin (do podglądu MSdistribution\*, MSmerge\*, MSrepl\*) 
- (Opcjonalnie) Skonfigurowany Database Mail i Operator dla powiadomień mailowych

## 🚀 Szybki start
1. Otwórz folder w VS Code.
2. Skonfiguruj serwer docelowy w `.config\env.json` (Server, Database, Distributor).
3. Uruchom task: **SQL: 1 – Jobs status** (Ctrl+Shift+B → wybierz zadanie), albo odpal bezpośrednio pliki z `sql/`.

## 🧭 Parametry środowiska
Plik `.config/env.json`:
```json
{
  "Server": ".",
  "PublisherDB": "YourPublisherDB",
  "Publication": "YourPublicationName",
  "Subscriber": "YourSubscriberServer",
  "SubscriberDB": "YourSubscriberDB",
  "DistributorDB": "distribution",
  "MailOperator": "DBA-OnCall"
}
```

## 🔔 Job mailowy
Skrypt `sqlagent/Create-ReplicationErrorEmailJob.sql` tworzy joba, który co godzinę wysyła e-mail z nowymi błędami z `MSrepl_errors`.
Ustaw nazwę operatora/Database Mail w pliku lub przekaż parametry w edytorze.

---

Licencja: MIT. Przyjemnego polowania na gremliny replikacji!
