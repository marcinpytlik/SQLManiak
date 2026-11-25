# SQLManiak Daily Health Check v1.7

**Instrukcja produkcyjna:** [Architektura, instalacja i eksploatacja](PRODUCTION_DEPLOYMENT.md).

Repozytorium i instalatory: SQL Server 2022+. Źródło SQL Server 2019 wymaga osobnego pilotażu; SQL Server 2016 poza zakresem. Wymagany zewnętrzny plik `SQLManiak_Daily_Health_Check_v1_5_CSV.sql` (nie jest częścią Git).

- 37: czysta instalacja centralnego repozytorium (alternatywnie 34 i modularne definicje).
- 38: konta i uprawnienia źródeł (alternatywnie 35).
- 39 / 40: XE i walidacja; [szczegóły](41_PRODUCTION_XE_DEPLOYMENT.md).
- 03 / 06: kolektor i runner; 16 / 17: Windows DPAPI i wrapper.
- 10 / 45 / 50: kontrole; 21 / 24: audyty.

Nie uruchamiać instalatorów wielopartiowych bez zatrzymania po błędzie. Brak automatycznej retencji i aktywnych sond domyślnie. Nie commitować poświadczeń.

[Archiwum LAB, Docker i kompletna historia testów](https://github.com/marcinpytlik/SQLManiak/tree/archive/dhc-v1.7-lab-20261125/tools/SQLManiakDailyHealthCheck/v1.7). Skrypty laboratoryjne usunięto z katalogu produkcyjnego, nie z historii Git. Wyniki operatora z 25.11.2026: 22 pomiary (18 COMPLETE / 4 kontrolowane PARTIAL), testy retencji zakończone. Pozostałe ograniczenia i bramki pilotażu opisano w instrukcji.
