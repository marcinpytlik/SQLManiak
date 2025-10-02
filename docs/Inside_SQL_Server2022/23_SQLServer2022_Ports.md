# 📡 SQL Server – Lista portów i usług

Poniższa tabela przedstawia domyślne porty używane przez różne usługi SQL Server i narzędzia klienckie (np. SSMS).  

| Usługa / komponent                  | Port domyślny | Protokół | Uwagi                                                                 |
|-------------------------------------|---------------|----------|----------------------------------------------------------------------|
| **SQL Server Database Engine**      | 1433          | TCP      | Domyślny port instancji podstawowej (TDS – Tabular Data Stream).     |
| **SQL Browser**                     | 1434          | UDP      | Lokalizuje porty instancji nazwanych.                               |
| **SQL Server (instancja nazwana)**  | Dynamiczny    | TCP      | Port ustalany przy starcie; sprawdzisz w Configuration Manager.      |
| **Service Broker**                   | 4022          | TCP      | Można zmienić.                                                       |
| **DAC (Dedicated Admin Connection)**| 1434 / dyn.   | TCP      | Zdalnie tylko, jeśli włączone.                                       |
| **Replication**                      | 1433 / dyn.   | TCP      | Wykorzystuje standardowe porty silnika SQL.                          |
| **Database Mirroring / AG Endpoint**| 5022          | TCP      | Może być zmieniony przy konfiguracji.                               |
| **Analysis Services (SSAS, default)**| 2383          | TCP      | Port stały dla instancji domyślnej.                                  |
| **SSAS Redirector (nazwane)**       | 2382          | TCP      | Przekierowuje na dynamiczny port instancji nazwanej.                 |
| **SSAS – Tabular Browser**          | 2381          | TCP      | Dla trybu tabular (od SQL 2012).                                     |
| **SSAS dodatkowe**                  | 2393–2394     | TCP      | Rzadziej wykorzystywane.                                             |
| **Reporting Services (SSRS)**       | 80 / 443      | TCP      | Dostęp przez HTTP/HTTPS.                                             |
| **Integration Services (SSIS)**     | 135 + dyn.    | TCP      | Używa RPC/DCOM – port 135 + losowe z zakresu RPC.                    |
| **WMI / administracja zdalna**      | 135 + dyn.    | TCP      | WMI, DCOM, Policy Management w SSMS.                                |
| **Pliki zdalne / FILESTREAM**       | 445           | TCP/UDP  | Dostęp do udziałów plikowych (backup/restore z UNC, FILETABLE).      |

---

## 🖥️ SSMS (SQL Server Management Studio)
SSMS korzysta z portów serwera, do którego się łączy:
- **1433/TCP** – instancja domyślna.  
- **UDP 1434** – zapytania do SQL Browser.  
- **Dynamiczne TCP** – jeśli instancja działa na porcie dynamicznym.  
- **135/TCP + dynamiczne RPC** – przy funkcjach korzystających z WMI (np. Activity Monitor).  

---

## 🔍 Jak sprawdzić aktualne porty
SQL Server Error Log:
```sql
EXEC xp_readerrorlog 0, 1, N'Server is listening';
```

PowerShell (rejestr):
```powershell
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQLServer\SuperSocketNetLib\Tcp\IPAll"
```
