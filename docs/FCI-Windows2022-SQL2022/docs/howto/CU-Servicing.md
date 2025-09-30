# Patchowanie SQL Server 2022 FCI — runbook (CU)

Model: **rolling upgrade** z zachowaniem dostępności.

## 0) Pre‑checks
```powershell
# wersja na obu węzłach
sqlcmd -S SQLSRV-FCI -Q "SELECT @@VERSION;"
Get-ClusterGroup "SQL Server (MSSQLSERVER)" | fl Name,OwnerNode,State
```

## 1) Patchuj węzeł pasywny
Na węźle **niebędącym** właścicielem roli SQL:
1. Pobierz najnowsze **CU dla SQL 2022** (EXE).
2. Uruchom jako admin:
   ```powershell
   Start-Process -FilePath .\SQLServer2022-KBxxxxxxx-x64.exe -ArgumentList "/Quiet","/Action=Patch","/IAcceptSQLServerLicenseTerms" -Wait
   ```

## 2) Przełącz FCI
```powershell
Move-ClusterGroup "SQL Server (MSSQLSERVER)" -Node DRUGI_WĘZEŁ
```

## 3) Patchuj drugi węzeł
Na teraz **pasywnym**:
```powershell
Start-Process -FilePath .\SQLServer2022-KBxxxxxxx-x64.exe -ArgumentList "/Quiet","/Action=Patch","/IAcceptSQLServerLicenseTerms" -Wait
```

## 4) Walidacja
```powershell
sqlcmd -S SQLSRV-FCI -Q "SELECT @@VERSION, SERVERPROPERTY('ProductLevel'), SERVERPROPERTY('ProductUpdateLevel');"
Get-ClusterGroup "SQL Server (MSSQLSERVER)" | fl Name,OwnerNode,State
```

## 5) Uwagi
- Pamiętaj o zgodności **sterowników ODBC** po stronie klientów.
- Jeśli korzystasz z szyfrowania: po CU sprawdź, czy certyfikat nadal jest podpięty i `ForceEncryption` nie został zmieniony przez instalator.
- Jeśli w CU są zmiany w komponentach współdzielonych, instalator zaktualizuje je na każdym węźle osobno.
