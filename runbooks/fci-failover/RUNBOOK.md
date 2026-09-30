# SQL Server FCI Failover — RUNBOOK

## 1. Zapisz czas rozpoczęcia

Potrzebujesz go do pomiaru czasu przełączenia i wpływu na aplikację.

## 2. Potwierdź current owner

```powershell
Get-ClusterGroup "SQL Server (MSSQLSERVER)"
```

Zapisz obecny node.

## 3. Wykonaj kontrolowany failover

Wzorzec używany przez repozytoryjny smoke test:

```powershell
Move-ClusterGroup "SQL Server (MSSQLSERVER)" -Node <TargetNode>
```

Nie wykonuj dodatkowych zmian konfiguracji w trakcie samego przełączenia.

## 4. Obserwuj stan grupy

```powershell
Get-ClusterGroup "SQL Server (MSSQLSERVER)"
Get-ClusterResource
```

Poczekaj, aż wymagane zasoby osiągną stan online.

## 5. Sprawdź połączenie przez VNN

Repozytoryjny smoke test używa:

```powershell
sqlcmd -S <VNN> -l 60 -Q "SELECT @@SERVERNAME AS NodeName, SYSDATETIMEOFFSET() AS Now;"
```

W labie:

```text
VNN = SQLSRV-FCI
```

## 6. Przejdź do walidacji

Wykonaj pełny zestaw z [VALIDATION.md](VALIDATION.md).
