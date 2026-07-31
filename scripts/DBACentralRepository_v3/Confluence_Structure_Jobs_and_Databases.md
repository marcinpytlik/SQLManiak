# Struktura Confluence — Joby SQL Server Agent i Bazy danych

# 1. SQL Server — Joby SQL Server Agent

```text
SQL Server — Joby SQL Server Agent
│
├── 01. Dashboard środowiska
│   ├── Podsumowanie jobów
│   ├── Podsumowanie kategorii jobów
│   ├── Joby wymagające uwagi
│   ├── Ostatnie błędy
│   ├── Ostatnie zmiany
│   ├── Dashboard zgodności
│   ├── Dashboard zmian
│   └── Instancje objęte monitoringiem
│
├── 02. Rejestr jobów
│   ├── Wszystkie joby
│   ├── Joby aktywne
│   ├── Joby wyłączone
│   ├── Joby bez harmonogramu
│   ├── Joby z wyłączonym harmonogramem
│   ├── Joby bez powiadomień
│   ├── Joby bez proxy
│   ├── Joby z retry
│   ├── Joby bez retry
│   ├── Joby z plikiem wyjściowym
│   ├── Joby wielokrokowe
│   ├── Joby z wieloma harmonogramami
│   ├── Joby niesklasyfikowane
│   ├── Kategorie funkcjonalne
│   │   ├── Joby backupowe
│   │   ├── Joby CHECKDB
│   │   ├── Joby utrzymania indeksów
│   │   ├── Joby aktualizacji statystyk
│   │   ├── Joby maintenance
│   │   ├── Joby czyszczenia i retencji
│   │   ├── Joby replikacji
│   │   ├── Joby HA i DR
│   │   ├── Joby ETL i integracyjne
│   │   ├── Joby raportowe
│   │   ├── Joby monitorujące i alertujące
│   │   ├── Joby bezpieczeństwa i audytu
│   │   └── Joby Database Mail
│   ├── Kategorie techniczne
│   │   ├── Joby T-SQL
│   │   ├── Joby PowerShell
│   │   ├── Joby CmdExec
│   │   └── Joby SSIS
│   └── SQL Server Reporting Services
│       ├── Joby SSRS
│       ├── Joby GUID bez mapowania
│       ├── Mapowanie jobów SSRS
│       └── Podsumowanie mapowania SSRS
│
├── 03. Dokumentacja jobów
│   ├── Rejestr dokumentacji jobów
│   ├── Status dokumentacji
│   ├── Joby bez dokumentacji
│   ├── Dokumentacja bez przeglądu
│   ├── Dokumentacja nieaktualna
│   ├── Dokumentacja zatwierdzona
│   ├── Cykl życia dokumentacji
│   │   ├── MISSING
│   │   ├── GENERATED
│   │   ├── IN_REVIEW
│   │   ├── APPROVED
│   │   ├── OUTDATED
│   │   └── RETIRED
│   └── Strony poszczególnych jobów
│       ├── PROD
│       ├── TEST
│       └── DEV
│
├── 04. Checklisty
│   ├── 04-1 Codzienna kontrola jobów
│   ├── 04-2 Cotygodniowy przegląd jobów
│   ├── 04-3 Miesięczny audyt konfiguracji
│   ├── 04-4 Checklista błędu joba
│   ├── 04-5 Checklista jobów backupowych
│   ├── 04-6 Checklista jobów SSIS
│   ├── 04-7 Checklista jobów PowerShell
│   ├── 04-8 Checklista po failover
│   └── 04-9 Checklista po migracji serwera
│
├── 05. Procedury operacyjne
│   ├── Tworzenie nowego joba
│   ├── Zmiana istniejącego joba
│   ├── Wyłączanie joba
│   ├── Usuwanie joba
│   ├── Przywracanie joba
│   ├── Zmiana właściciela
│   ├── Zmiana harmonogramu
│   ├── Zmiana operatora
│   ├── Konfiguracja proxy
│   ├── Konfiguracja retry
│   └── Konfiguracja pliku wyjściowego
│
├── 06. Procedury diagnostyczne
│   ├── Historia joba
│   ├── Pierwszy błędny krok
│   ├── Pełny komunikat błędu
│   ├── Kontekst bezpieczeństwa
│   ├── Harmonogram joba
│   ├── Nakładanie się jobów
│   ├── Status SQL Server Agent
│   ├── Database Mail
│   ├── PowerShell i CmdExec
│   ├── SSIS
│   ├── Błędy kolektora
│   └── Błędy skanowania
│
├── 07. Standardy
│   ├── Standard nazw jobów
│   ├── Standard nazw kroków
│   ├── Standard właścicieli
│   ├── Standard harmonogramów
│   ├── Standard powiadomień
│   ├── Standard retry
│   ├── Standard logowania błędów
│   ├── Standard plików wyjściowych
│   ├── Standard proxy i credentials
│   ├── Standard jobów PowerShell
│   ├── Standard jobów SSIS
│   ├── Standard jobów backupowych
│   ├── Standard jobów HA i DR
│   ├── Standard wdrażania zmian
│   └── Minimalny standard joba produkcyjnego
│
├── 08. Monitoring i raportowanie
│   ├── Raport dzienny
│   ├── Raport tygodniowy
│   ├── Raport miesięczny
│   ├── Joby wymagające uwagi
│   ├── Błędy skanowania
│   ├── Historia uruchomień audytu
│   ├── Nieudane uruchomienia audytu
│   ├── Historia raportów
│   └── Podsumowanie eksportu
│
├── 09. Audyt i zgodność
│   ├── Dashboard zgodności
│   ├── Wyniki audytu zgodności
│   ├── Otwarte findingi
│   ├── Findingi krytyczne
│   ├── Audyt właścicieli jobów
│   ├── Audyt kont proxy
│   ├── Audyt harmonogramów
│   ├── Audyt powiadomień
│   ├── Audyt jobów wyłączonych
│   ├── Audyt nieudokumentowanych jobów
│   ├── Rejestr dokumentacji jobów
│   ├── Dokumentacja bez przeglądu
│   ├── Dokumentacja nieaktualna
│   ├── Aktywne wyjątki
│   ├── Wygasłe wyjątki
│   ├── Wyjątki wygasające w ciągu 30 dni
│   ├── Wyjątki bez numeru zgłoszenia
│   ├── Reguły audytu
│   ├── Wyłączone reguły audytu
│   ├── Podsumowanie według reguły
│   ├── Podsumowanie według ważności
│   ├── Podsumowanie według instancji
│   ├── Joby z największą liczbą niezgodności
│   └── Kolejka działań naprawczych
│
├── 10. Zmiany i cykl życia
│   ├── Dashboard zmian
│   ├── Rejestr zmian
│   ├── Nowe joby
│   ├── Usunięte joby
│   ├── Zmodyfikowane joby
│   ├── Zmiany właścicieli
│   ├── Zmiany statusu jobów
│   ├── Joby włączone
│   ├── Joby wyłączone
│   ├── Zmiany kroków
│   ├── Zmiany komend
│   ├── Zmiany harmonogramów
│   ├── Zmiany operatorów
│   ├── Zmiany powiadomień
│   ├── Zmiany proxy
│   ├── Zmiany kategorii
│   ├── Zmiany opisów
│   ├── Zmiany autoryzowane
│   ├── Zmiany nieautoryzowane
│   ├── Zmiany niezweryfikowane
│   ├── Zmiany bez numeru zgłoszenia
│   ├── Zmiany z ostatnich 24 godzin
│   ├── Zmiany z ostatnich 7 dni
│   ├── Zmiany z ostatnich 30 dni
│   ├── Zmiany krytyczne
│   ├── Ostatnia zmiana każdego joba
│   ├── Joby często zmieniane
│   ├── Podsumowanie zmian
│   ├── Dzienne podsumowanie zmian
│   └── Podsumowanie zmian według instancji
│
├── 11. Bezpieczeństwo
│   ├── Konta właścicieli jobów
│   ├── Proxy SQL Server Agent
│   ├── Credentials
│   ├── Uprawnienia subsystemów
│   ├── Konta usługowe
│   ├── Joby uruchamiane jako konto Agenta
│   ├── Joby PowerShell bez proxy
│   ├── Joby CmdExec bez proxy
│   └── Joby SSIS bez proxy
│
├── 12. Zależności
│   ├── Bazy danych używane przez joby
│   ├── Serwery połączone
│   ├── Udziały sieciowe
│   ├── Pliki i katalogi
│   ├── Pakiety SSIS
│   ├── Raporty SSRS
│   ├── Procedury składowane
│   ├── Konta proxy
│   ├── Operatorzy
│   └── Zależności między jobami
│
├── 13. Incydenty i problemy
│   ├── Otwarte problemy
│   ├── Znane problemy
│   ├── Historia incydentów
│   ├── Joby cyklicznie kończące się błędem
│   ├── Joby przekraczające czas wykonania
│   ├── Joby nakładające się
│   ├── Problemy z Database Mail
│   ├── Problemy z proxy
│   ├── Problemy z SSIS
│   └── Problemy z SSRS
│
└── 99. Archiwum
    ├── Historyczne raporty
    ├── Usunięte joby
    ├── Wycofana dokumentacja
    ├── Zamknięte findingi
    ├── Wygasłe wyjątki
    └── Stare wersje standardów
```

# 2. SQL Server — Bazy danych

```text
SQL Server — Bazy danych
│
├── 01. Dashboard środowiska
│   ├── Podsumowanie wszystkich baz
│   ├── Liczba baz według środowiska
│   ├── Liczba baz według instancji
│   ├── Bazy wymagające uwagi
│   ├── Bazy niedostępne
│   ├── Bazy w stanie innym niż ONLINE
│   ├── Bazy bez poprawnego backupu
│   ├── Bazy bez CHECKDB
│   ├── Bazy z wysokim ryzykiem pojemności
│   ├── Bazy w HA i DR
│   └── Ostatnie błędy kolektora
│
├── 02. Rejestr baz danych
│   ├── Wszystkie bazy
│   ├── Bazy produkcyjne
│   ├── Bazy testowe
│   ├── Bazy deweloperskie
│   ├── Bazy systemowe
│   ├── Bazy użytkownika
│   ├── Bazy aktywne
│   ├── Bazy wyłączone z monitoringu
│   ├── Bazy OFFLINE
│   ├── Bazy RESTORING
│   ├── Bazy RECOVERY_PENDING
│   ├── Bazy SUSPECT
│   ├── Bazy READ_ONLY
│   ├── Bazy bez właściciela biznesowego
│   ├── Bazy bez właściciela technicznego
│   └── Bazy nieudokumentowane
│
├── 03. Dokumentacja baz
│   ├── Rejestr dokumentacji
│   ├── Bazy bez dokumentacji
│   ├── Dokumentacja niekompletna
│   ├── Dokumentacja bez przeglądu
│   ├── Dokumentacja nieaktualna
│   ├── Dokumentacja zatwierdzona
│   └── Strony poszczególnych baz
│       ├── PROD
│       ├── TEST
│       └── DEV
│
├── 04. Pojemność i wzrost
│   ├── Rozmiary baz
│   ├── Rozmiary plików danych
│   ├── Rozmiary plików logu
│   ├── Wolne miejsce w plikach
│   ├── Wolne miejsce na wolumenach
│   ├── Autogrowth
│   ├── Historia wzrostu
│   ├── Prognoza pojemności
│   ├── Bazy wymagające powiększenia
│   ├── Logi o wysokim procentowym użyciu
│   ├── Największe bazy
│   ├── Najszybciej rosnące bazy
│   ├── Największe tabele
│   └── Ryzyko pojemności
│
├── 05. Pliki i filegroupy
│   ├── Pliki danych
│   ├── Pliki logu
│   ├── Filegroupy
│   ├── PRIMARY filegroup
│   ├── Dodatkowe filegroupy
│   ├── FILESTREAM
│   ├── Rozmieszczenie plików
│   ├── Standard nazw plików
│   ├── Standard autogrowth
│   ├── Pliki o nietypowej konfiguracji
│   └── Pliki wymagające uwagi
│
├── 06. Backup i odtwarzanie
│   ├── Status backupów
│   ├── Backup FULL
│   ├── Backup DIFF
│   ├── Backup LOG
│   ├── Bazy bez backupu FULL
│   ├── Bazy bez backupu DIFF
│   ├── Bazy bez backupu LOG
│   ├── Backupy przeterminowane
│   ├── Backupy COPY_ONLY
│   ├── Historia backupów
│   ├── Czas trwania backupów
│   ├── Rozmiary backupów
│   ├── Kompresja backupów
│   ├── Szyfrowanie backupów
│   ├── Retencja backupów
│   ├── Lokalizacje plików backupowych
│   ├── Testy odtworzeniowe
│   ├── Historia restore
│   ├── RPO
│   ├── RTO
│   └── Bazy bez potwierdzonego testu restore
│
├── 07. HA i DR
│   ├── Availability Groups
│   ├── Repliki AG
│   ├── Bazy w AG
│   ├── Stan synchronizacji
│   ├── Kolejka wysyłania logu
│   ├── Kolejka redo
│   ├── Tryb synchronizacji
│   ├── Preferencje backupu
│   ├── Automatyczny failover
│   ├── Log Shipping
│   ├── Mirroring
│   ├── Failover Cluster Instance
│   ├── Bazy bez ochrony HA
│   ├── Bazy bez ochrony DR
│   ├── Testy failover
│   ├── Testy DR
│   └── Historia incydentów HA i DR
│
├── 08. Bezpieczeństwo
│   ├── Właściciele baz
│   ├── Użytkownicy bazodanowi
│   ├── Role bazodanowe
│   ├── Członkostwa w rolach
│   ├── Uprawnienia jawne
│   ├── Użytkownicy osieroceni
│   ├── Konta nieaktywne
│   ├── Konta aplikacyjne
│   ├── Konta techniczne
│   ├── Audyt dostępu
│   ├── Transparent Data Encryption
│   ├── Always Encrypted
│   ├── Row-Level Security
│   ├── Dynamic Data Masking
│   ├── Klucze i certyfikaty
│   ├── Szyfrowanie backupów
│   ├── Klasyfikacja danych
│   └── Przeglądy uprawnień
│
├── 09. Konfiguracja baz
│   ├── Recovery model
│   ├── Compatibility level
│   ├── Auto Close
│   ├── Auto Shrink
│   ├── Auto Create Statistics
│   ├── Auto Update Statistics
│   ├── Auto Update Statistics Async
│   ├── Query Store
│   ├── Read Committed Snapshot
│   ├── Snapshot Isolation
│   ├── Accelerated Database Recovery
│   ├── Delayed Durability
│   ├── Page Verify
│   ├── Trustworthy
│   ├── Broker Enabled
│   ├── Change Data Capture
│   ├── Change Tracking
│   ├── Temporal Tables
│   ├── Database Scoped Configurations
│   └── Odchylenia od standardu
│
├── 10. Integralność i maintenance
│   ├── Status CHECKDB
│   ├── Historia CHECKDB
│   ├── Bazy bez aktualnego CHECKDB
│   ├── Wyniki DBCC CHECKDB
│   ├── Suspect Pages
│   ├── Uszkodzenia logiczne
│   ├── Uszkodzenia fizyczne
│   ├── Maintenance indeksów
│   ├── Aktualizacja statystyk
│   ├── Fragmentacja indeksów
│   ├── Statystyki nieaktualne
│   ├── Cleanup historii
│   ├── Cleanup backup history
│   ├── Cleanup job history
│   └── Standard maintenance
│
├── 11. Wydajność
│   ├── Query Store
│   ├── Najdroższe zapytania
│   ├── Najczęstsze zapytania
│   ├── Regresje planów
│   ├── Wymuszone plany
│   ├── Wait Statistics
│   ├── Blokady
│   ├── Deadlocki
│   ├── Długie transakcje
│   ├── Tempdb usage
│   ├── Log usage
│   ├── Indeksy brakujące
│   ├── Indeksy nieużywane
│   ├── Statystyki
│   ├── Parameter sniffing
│   └── Zalecenia optymalizacyjne
│
├── 12. Zależności
│   ├── Joby SQL Server Agent
│   ├── Procedury składowane
│   ├── Widoki
│   ├── Funkcje
│   ├── Synonimy
│   ├── Serwery połączone
│   ├── Replikacja
│   ├── SSIS
│   ├── SSRS
│   ├── Power BI
│   ├── Aplikacje
│   ├── Konta aplikacyjne
│   ├── Udziały sieciowe
│   ├── Pliki zewnętrzne
│   └── Inne bazy danych
│
├── 13. Checklisty
│   ├── Codzienna kontrola baz
│   ├── Cotygodniowy przegląd baz
│   ├── Miesięczny audyt konfiguracji
│   ├── Checklista nowej bazy
│   ├── Checklista migracji bazy
│   ├── Checklista po restore
│   ├── Checklista po failover
│   ├── Checklista przed usunięciem bazy
│   ├── Checklista testu DR
│   └── Checklista zmiany compatibility level
│
├── 14. Incydenty i problemy
│   ├── Otwarte incydenty
│   ├── Znane problemy
│   ├── Bazy niedostępne
│   ├── Bazy SUSPECT
│   ├── Bazy RECOVERY_PENDING
│   ├── Problemy z logiem transakcyjnym
│   ├── Problemy z tempdb
│   ├── Problemy z backupem
│   ├── Problemy z restore
│   ├── Problemy z CHECKDB
│   ├── Problemy z AG
│   ├── Problemy z Log Shipping
│   ├── Problemy z przestrzenią
│   ├── Problemy z wydajnością
│   └── Historia incydentów
│
├── 15. Raporty
│   ├── Raport dzienny
│   ├── Raport tygodniowy
│   ├── Raport miesięczny
│   ├── Raport pojemności
│   ├── Raport backupów
│   ├── Raport integralności
│   ├── Raport bezpieczeństwa
│   ├── Raport HA i DR
│   ├── Raport konfiguracji
│   ├── Raport zmian
│   ├── Raport baz wymagających uwagi
│   └── Historia raportów
│
├── 16. Standardy
│   ├── Standard nazw baz
│   ├── Standard właścicieli baz
│   ├── Standard plików danych
│   ├── Standard plików logu
│   ├── Standard filegroup
│   ├── Standard autogrowth
│   ├── Standard recovery model
│   ├── Standard compatibility level
│   ├── Standard Query Store
│   ├── Standard backupów
│   ├── Standard CHECKDB
│   ├── Standard bezpieczeństwa
│   ├── Standard monitoringu
│   ├── Standard dokumentacji
│   ├── Minimalny standard bazy PROD
│   └── Kody naruszeń standardów
│
├── 17. Zmiany i cykl życia
│   ├── Rejestr zmian
│   ├── Nowe bazy
│   ├── Usunięte bazy
│   ├── Zmiany właściciela
│   ├── Zmiany recovery model
│   ├── Zmiany compatibility level
│   ├── Zmiany konfiguracji
│   ├── Zmiany plików
│   ├── Zmiany autogrowth
│   ├── Zmiany Query Store
│   ├── Zmiany bezpieczeństwa
│   ├── Zmiany HA i DR
│   ├── Zmiany autoryzowane
│   ├── Zmiany nieautoryzowane
│   ├── Zmiany bez numeru zgłoszenia
│   ├── Migracje
│   ├── Konsolidacje
│   ├── Wycofanie bazy
│   └── Archiwizacja bazy
│
└── 99. Archiwum
    ├── Usunięte bazy
    ├── Wycofane bazy
    ├── Historyczne raporty
    ├── Zamknięte incydenty
    ├── Zamknięte findingi
    ├── Wygasłe wyjątki
    ├── Stare wersje dokumentacji
    └── Stare wersje standardów
```

# 3. Rekomendowany podział przestrzeni

```text
SQL Server
├── SQL Server — Joby SQL Server Agent
└── SQL Server — Bazy danych
```
