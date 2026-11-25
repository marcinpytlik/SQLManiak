# SQLManiak Daily Health Check v1.7

**Dokumentacja:** [Architektura](07_Documentation/ARCHITECTURE.md) · [Instalacja i eksploatacja](07_Documentation/PRODUCTION_DEPLOYMENT.md) · [Audyt SQL](07_Documentation/SOURCE_SQL_AUDIT.md).

Repozytorium i instalatory: SQL Server 2022+. Źródło SQL Server 2019 wymaga osobnego pilotażu; SQL Server 2016 poza zakresem. Wymagany bazowy skrypt [SQLManiak_Daily_Health_Check_v1_5_CSV.sql](03_Collector/SQLManiak_Daily_Health_Check_v1_5_CSV.sql) jest teraz częścią pakietu. Nie trzeba kopiować go z innego repozytorium.

SHA256 audytowanej wersji: `8978B06A630F24D672EDD78721B1B8A4A84DD6CCC724B9B87DF4DBB847DA67B8`. `.gitattributes` wyłącza normalizację zakończeń linii dla tego pliku. Przed wdrożeniem sprawdzić hash; audyt statyczny nie zastępuje pilotażu.

- 37: czysta instalacja centralnego repozytorium (alternatywnie 34 i modularne definicje).
- 38: konta i uprawnienia źródeł (alternatywnie 35).
- 39 / 40: XE i walidacja; [szczegóły](07_Documentation/41_PRODUCTION_XE_DEPLOYMENT.md).
- 03 / 06: kolektor i runner; 16 / 17: Windows DPAPI i wrapper.
- 10 / 45 / 50: kontrole; 21 / 24: audyty.

Nie uruchamiać instalatorów wielopartiowych bez zatrzymania po błędzie. Brak automatycznej retencji i aktywnych sond domyślnie. Nie commitować poświadczeń.

[Archiwum LAB, Docker i kompletna historia testów](https://github.com/marcinpytlik/SQLManiak/tree/archive/dhc-v1.7-lab-20261125/tools/SQLManiakDailyHealthCheck/v1.7). Skrypty laboratoryjne usunięto z katalogu produkcyjnego, nie z historii Git. Wyniki operatora z 25.11.2026: 22 pomiary (18 COMPLETE / 4 kontrolowane PARTIAL), testy retencji zakończone. Pozostałe ograniczenia i bramki pilotażu opisano w instrukcji.

## Struktura pakietu

| Katalog | Przeznaczenie |
|---|---|
| [01_Installation](01_Installation/) | Instalatory repozytorium i źródeł |
| [02_Repository](02_Repository/) | Definicje tabel, procedur i widoków |
| [03_Collector](03_Collector/) | Kolektor i wszystkie zapytania źródłowe |
| [04_Configuration](04_Configuration/) | DPAPI i scheduler |
| [05_Validation](05_Validation/) | Audyt, kontrola pakietu i źródeł |
| [06_Reporting](06_Reporting/) | Kontrole DBA i granty Grafana |
| [07_Documentation](07_Documentation/) | Dokumentacja |

Z katalogu głównego v1.7 uruchom ` .\05_Validation\Test-DHC-Package.ps1 ` przed wdrożeniem. Nie spłaszczaj katalogów. Instalator modularny odczytuje 02_Repository; scheduler odwołuje się do 03_Collector.
