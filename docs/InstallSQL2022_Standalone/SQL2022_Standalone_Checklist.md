# ✅ Checklista: Instalacja SQL Server 2022 Standalone w domenie

## 1. Przygotowanie systemu operacyjnego
- [ ] Windows Server 2022 (GUI/Core) z aktualizacjami.
- [ ] Dołączenie do domeny AD.
- [ ] Statyczny adres IP i DNS na DC.
- [ ] Zsynchronizowany czas (NTP) i strefa czasowa.
- [ ] Zapora włączona; wyjątek dla portu SQL (np. 1433).
- [ ] Konta instalujące mają lokalne uprawnienia administratora.

## 2. Przygotowanie dysków
- [ ] C: system
- [ ] D: dane (MDF/NDF)
- [ ] L: log (LDF)
- [ ] T: tempdb
- [ ] B: backup

## 3. Konta serwisowe
- [ ] Utworzone konta domenowe lub gMSA:
  - DOMENA\sqlsvc – SQL Server Engine
  - DOMENA\sqlagent – SQL Server Agent (lub gMSA)
- [ ] Nadane prawa lokalne:
  - Log on as a service
  - Perform volume maintenance tasks (dla Engine)
- [ ] Konto instalujące ma prawa do tworzenia folderów na D:/L:/T:/B:

## 4. Co przed
- [ ] .NET Framework 4.8
- [ ] Paczka instalacyjna SQL 2022 dostępna lokalnie (np. D:\SQL2022\setup.exe)

## 5. Instalacja SQL Server 2022
- [ ] New SQL Server stand-alone installation
- [ ] Feature’y: Database Engine Services, SQL Server Agent (+ opcjonalne Full-Text/SSIS/PolyBase/SSRS)
- [ ] Instance name: MSSQLSERVER (lub nazwana)
- [ ] Root directory: C:\Program Files\Microsoft SQL Server
- [ ] Data root: D:\MSSQL\Data
- [ ] Logs: L:\MSSQL\Logs
- [ ] TempDB: T:\MSSQL\TempDB
- [ ] Backup: B:\MSSQL\Backup

## 6. Konfiguracja serwisów
- [ ] SQL Server Engine → DOMENA\sqlsvc (lub gMSA)
- [ ] SQL Server Agent → DOMENA\sqlagent (lub gMSA)
- [ ] Startup type: Automatic

## 7. Konfiguracja instancji (instalator)
- [ ] Collation: SQL_Latin1_General_CP1_CI_AS (lub wymagana)
- [ ] Authentication: Mixed Mode (SQL + Windows) lub tylko Windows
- [ ] Sysadmin: konto instalujące + grupa DBA
- [ ] TempDB: liczba plików = liczba rdzeni (max 8), rozmiary startowe >= 512 MB, autogrowth stały

## 8. Finalizacja instalacji
- [ ] Setup rules: PASS
- [ ] Instalacja bez błędów
- [ ] Restart (zalecany)

## 9. Po instalacji
- [ ] Instalacja najnowszego CU dla SQL Server 2022
- [ ] Włącz TCP/IP, ustaw port (np. 1433/niestandardowy)
- [ ] Włącz Instant File Initialization (przywilej SeManageVolumePrivilege)
- [ ] Domyślne ścieżki nowych baz → D:/L:/B:
- [ ] Skonfigurowany model backupów (FULL/DIFF/LOG)
- [ ] Monitoring: XE, Query Store, integracja z Grafana/Telegraf/InfluxDB

## 10. Weryfikacja
- [ ] Logowanie kontem domenowym i SQL (jeśli włączone)
- [ ] Utworzenie/test bazy; test backup/restore
- [ ] Test łączności z innego hosta (sqlcmd/aplikacja)
- [ ] Prosty test wydajności tempdb i I/O
