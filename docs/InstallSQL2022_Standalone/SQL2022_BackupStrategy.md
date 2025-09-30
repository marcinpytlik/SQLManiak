# 💾 SQL Server 2022 – Backup Strategy

## Rodzaje kopii zapasowych
- FULL – pełna kopia bazy.
- DIFF – różnicowa, tylko zmiany od ostatniego FULL.
- LOG – transakcyjna, dla modelu FULL/BULK_LOGGED.

## Rekomendacje
- Systemowe bazy (master, msdb, model) – FULL raz dziennie.
- TempDB – nie backupujemy (tworzona przy starcie).
- Bazy użytkownika:
  - FULL – codziennie w nocy.
  - DIFF – co 4 godziny.
  - LOG – co 15 minut.

## Parametry
- COPY_ONLY dla backupów ad-hoc.
- Kompresja (`WITH COMPRESSION`) – oszczędność miejsca.
- Szyfrowanie (`WITH ENCRYPTION`) – klucz certyfikatu/asym.
- Retencja – zgodnie z polityką (np. 14 dni na dysku, 30 w archiwum).
