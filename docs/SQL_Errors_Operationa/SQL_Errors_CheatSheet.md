# SQL Server – Najczęstsze błędy natywne (Cheat Sheet)

| Error | Znaczenie | Typowe przyczyny | Szybki Fix |
|-------|-----------|------------------|------------|
| 17    | Server does not exist / access denied | Usługa zatrzymana, zła nazwa, port/firewall | Sprawdź usługę, DNS, port 1433, firewall |
| 53    | SQL Server not found (Named Pipes) | Klient łączy się przez NP, serwer niedostępny | Wymuś TCP/IP, sprawdź firewall |
| 258   | Connection timeout | Sieć wolna/zablokowana | Test-NetConnection, firewall, routing |
| 18456 | Login failed | Błędny login/hasło, brak uprawnień, zły auth mode | ERRORLOG → state code, popraw login/hasło/uprawnienia |
| 4060  | Cannot open database | Baza offline, RESTORING, brak uprawnień | ONLINE bazę, nadaj uprawnienia |
| 823   | I/O error | Uszkodzony sektor/dysk | Event Log, storage check, DBCC CHECKDB |
| 824   | Logical consistency error | Uszkodzona strona danych | DBCC CHECKDB, restore z backupu |
| 825   | Read retry warning | Storage zwraca błędy odczytu | Monitoruj, sprawdź storage |
| 1101/1105 | Could not allocate space | Brak miejsca w bazie / pliku / na dysku | Zwiększ pliki, dodaj nowe, zwolnij miejsce |
| 5120  | Cannot open physical file | Brak dostępu do MDF/LDF | Sprawdź ścieżkę, ACL, dostępność dysku |
| 3958  | TempDB full | Brak miejsca w tempdb | Powiększ/ dodaj pliki tempdb |
| 1205  | Deadlock victim | Konflikt transakcji | Retry logic, zmiana kolejności locków |
| 3960  | Snapshot isolation aborted | Konflikt wersji | Ponów transakcję |
| 9002  | Transaction log full | Log pełny | Backup loga, powiększ, dodaj plik |
| 3013  | Backup/Restore error | Ogólny błąd operacji | Sprawdź inne błędy (3201/3313) |
| 3201  | Cannot open backup device | Brak dostępu do ścieżki backupu | Uprawnienia konta SQL, ścieżka |
| 3313  | Error during redo/undo (restore) | Problem przy odtwarzaniu | Sprawdź sekwencję backupów |

## TL;DR
- **Połączenie**: 17, 53, 258  
- **Login/Baza**: 18456, 4060  
- **Storage/I/O**: 823, 824, 825, 5120  
- **Miejsce**: 1101, 1105, 3958, 9002  
- **Transakcje**: 1205, 3960  
- **Backup/Restore**: 3013, 3201, 3313  
