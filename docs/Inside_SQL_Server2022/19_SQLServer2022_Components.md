# Komponenty Microsoft SQL Server — przegląd (skrócony)

_Opis głównych komponentów i ich roli._

---

## 1. Database Engine (główny komponent)
- **Relational (Query) Engine**: parser, optymalizator zapytań, executor (plan cache, statystyki). Odpowiada za przetwarzanie zapytań T-SQL.
- **Storage Engine**: buffer pool, page I/O, transaction log, lock/latch manager, recovery. Zarządza plikami danych (.mdf/.ndf) i logu (.ldf).
- **Pliki i struktury**: strony (8 KB), extent (64 KB), filegroups, VLF w logu, tempdb (tymczasowa baza).

## 2. Usługi systemowe (Windows services)
- **MSSQLSERVER / MSSQL$INSTANCENAME** — usługa Database Engine.
- **SQLSERVERAGENT** — SQL Server Agent (joby, harmonogramy, alerty).
- **SQLBrowser** — rozgłaszanie nazw instancji i portów (UDP 1434).
- **MSSQLFDLauncher / MSSQLLaunchpad** — uruchamianie zewnętrznych procesów (np. Machine Learning Services).
- **MSDTC** — Distributed Transaction Coordinator (przy rozproszonych transakcjach; nie zawsze konieczny).

## 3. Narzędzia i serwisy integracyjne (Platforma BI / ETL / Reporting)
- **SSIS (Integration Services)** — ETL: pakiety SSIS, kontrola przepływu danych, transformacje.
- **SSAS (Analysis Services)** — modele analityczne: tabular / multidimensional, OLAP, kalkulacje MDX/DAX.
- **SSRS (Reporting Services)** — serwer raportów, rendering (RDL), subskrypcje, web portal.
- **Power BI Report Server** — opcjonalny serwer raportów on-prem.

## 4. Funkcje rozszerzające i integracyjne
- **PolyBase** — dostęp do zewnętrznych źródeł (HDFS, Azure Blob, external tables).
- **Linked Servers** — łączenie heterogenicznych źródeł danych (inne SQL Server, Oracle, MySQL).
- **Machine Learning Services** — uruchamianie skryptów R/Python (external scripts).
- **CLR Integration** — uruchamianie .NET assemblies wewnątrz SQL Server.

## 5. Wysoka dostępność i disaster recovery (HA/DR)
- **Always On Availability Groups (AG)** — replikacja na poziomie bazy (synchronizacja, automatyczny failover, readable secondaries).
- **Failover Cluster Instance (FCI)** — HA na poziomie instancji (współdzielony storage, WSFC).
- **Log Shipping** — proste DR poprzez przesyłanie i apply logów.
- **Database Mirroring** — przestarzałe, historyczne (zastąpione przez AG).
- **Backup & Restore** — klasyczna metoda DR (offsite, cloud storage).

## 6. Replikacja i przesył danych
- **Snapshot / Transactional / Merge Replication** — scenariusze replikacji dla synchronizacji i rozproszenia danych.
- **Change Data Capture (CDC) / Change Tracking** — mechanizmy śledzenia zmian do integracji ETL/CDC workflows.

## 7. Bezpieczeństwo i szyfrowanie
- **Uwierzytelnianie**: Windows Auth (Kerberos/NTLM), SQL Auth.
- **Autoryzacja**: logins, users, server roles, database roles, granular permissions (GRANT/DENY).
- **Szyfrowanie**:
  - **TDE (Transparent Data Encryption)** — szyfruje pliki baz danych w spoczynku.
  - **Always Encrypted** — szyfrowanie po stronie klienta (kolumny).
  - **TLS** — szyfrowanie komunikacji sieciowej.
- **Key management**: Master Key, Database Encryption Key, certyfikaty, integracja z HSM / Azure Key Vault.
- **Audyt**: SQL Audit, Extended Events, built-in audit features.

## 8. Monitorowanie, diagnostyka i troubleshooting
- **DMV / DMF** (sys.dm_*) — dynamic management views / functions (monitoring runtime).
- **Extended Events (XE)** — lekki mechanizm śledzenia zdarzeń i diagnostyki.
- **Query Store** — historia planów i statystyk zapytań (plan forcing, regressing plans).
- **PerfMon / Windows counters** — CPU, memory, disk I/O, network.
- **SQL Server Error Log / Windows Event Log** — podstawowe logi serwera.

## 9. Optymalizacja i mechanizmy wydajnościowe
- **In-Memory OLTP** — memory-optimized tables, natively compiled procs.
- **Columnstore Indexes** — kolumnowy magazyn dla analityki (batch mode).
- **Resource Governor** — ograniczenie zasobów (CPU/IO) per workload group.
- **Partitioning** — partycjonowanie tabel i indeksów.
- **Parallelism / MAXDOP** — wykonanie równoległe zapytań.

## 10. Narzędzia deweloperskie i administracyjne
- **SSMS (SQL Server Management Studio)** — GUI admina.
- **VSCode** — lekkie, multiplatformowe.
- **sqlcmd / bcp** — CLI narzędzia (skrypty, bulk copy).
- **PowerShell (SqlServer module)** — automatyzacja i skrypty administracyjne.
- **SSDT / Visual Studio** — development DB projects, dacpac, schema compare.

## 11. Connectivity: protokoły i porty
- **TDS (Tabular Data Stream)** — protokół klient ↔ serwer.
- **Transporty**: TCP/IP (domyślnie port 1433), Named Pipes, Shared Memory.
- **SQL Server Browser** — UDP 1434 (named instances discovery).

## 12. Maintenance & tooling
- **SQL Server Agent Jobs** — harmonogramy backupów, maintenance plans, custom jobs.
- **DBCC CHECKDB** — integralność danych.
- **Index maintenance** — rebuild / reorganize, update statistics.
- **Maintenance Plans** — prostsze GUI do planowania zadań admina.

## 13. Dodatkowe komponenty i rozszerzenia
- **Full-Text Search** — indeksowanie pełnotekstowe i zapytania CONTAINS/FREETEXT.
- **Service Broker** — asynchroniczne komunikaty i kolejki w bazie danych.
- **Distributed Replay** — testy obciążeniowe (opcjonalne).
- **PolyBase connectors** — integracja z Hadoop / Data Lake.

---

## Przydatne referencje (szybkie)
- Usługi Windows: sprawdź `services.msc` oraz nazwy usług (MSSQLSERVER, SQLSERVERAGENT, SQLBrowser).  
- Porty: domyślnie TCP 1433 (default instance), Named instance może używać dynamicznego portu lub statycznego ustawionego.  
- Logi: SQL Server Errorlog (domyślnie w folderze `MSSQL\Log`), Event Viewer.

---

_ostatnia aktualizacja: 2025-09-16_
