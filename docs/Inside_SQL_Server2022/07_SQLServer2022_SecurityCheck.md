
---

# 2) 🔒 SQL Server 2022 — Security Hardening (checklista)

```markdown
# 🔒 SQL Server 2022 — Security Hardening Checklist

## Podstawa (instancja / OS)
- [ ] Aktualny **CU** + Windows Update (udokumentuj build).
- [ ] Konta usług: **gMSA** lub dedykowane, zasada least privilege.
- [ ] Zmiana portu TCP (stały), w razie potrzeby **odcięcie Browser**.
- [ ] Włącz **TLS 1.2+**; wyłącz przestarzałe protokoły szyfrowania na OS.
- [ ] Audyt logowania nieudanych (Windows Security Log) + SQL Audit (krytyczne akcje).

## Konfiguracja instancji
- [ ] Wyłącz nieużywane funkcje: xp_cmdshell, OLE Automation, Ad Hoc (sp_configure) – chyba że uzasadnione.
- [ ] Hasła/poświadczenia poza silnikiem (Secret Manager, DPAPI); brak haseł w repo.
- [ ] **Server roles**: brak użytkowników w sysadmin poza wyjątkami; dedykowane role serwisowe.
- [ ] **Contained DB** tylko gdy potrzebne; kontrola AUTH/schema separation.
- [ ] **Transparent Data Encryption (TDE)** dla krytycznych DB; kopia kluczy/certyfikatów (offline, zaszyfrowana).
- [ ] **Backup encryption** (AES-256); test restore (DR drill).
- [ ] **Database Scoped Config**: RCSI tylko gdy świadomie; MAXDOP/CTFP wg standardu.
- [ ] **Data masking** (DM), **Always Encrypted** dla PII/PAN, jeśli wymagania compliance.

## Siec
- [ ] Firewall: whitelist segmentów i admin jump-hostów.
- [ ] Endpointy: wyłącz zbędne; sprawdź **Mirroring/AG endpoints** (AUTH/ENCRYPTION).
- [ ] Zdalne narzędzia: RDP zamknięte; tylko bastion/Privileged Access Workstations.

## Audyt i logi
- [ ] SQL Audit → pliki `.sqlaudit` na dysku chronionym; retencja i backup.
- [ ] **system_health** aktywny, rotacja XE; dodatkowa sesja XE: failed logins, schema changes, role changes.
- [ ] ERRORLOG/Agent: retencja/rotacja; monitoring alertów.

## Uprawnienia / obiekty
- [ ] Brak **dbo** dla kont aplikacyjnych; dedykowane schematy.
- [ ] Minimalny `GRANT`/`DENY`; brak `CONTROL SERVER` dla kont operacyjnych.
- [ ] Przegląd **CLR** (SAFE only), brak UNSAFE bez oceny ryzyka.

## DR i klucze
- [ ] Eksport kluczy TDE/Cert do sejfu (oddzielne hasła); test odtworzenia na serwerze DR.
- [ ] Regularny **restore test** user DB + msdb/master/model (po migracjach).
- [ ] Dokument „runbook restore” (kroki + RTO/RPO).

## Automatyzacja i SDLC
- [ ] Skrypty DDL w repo; **migracje** (dacpac/liquibase/flyway) z przeglądem PR.
- [ ] Pipeline CI: skany bezpieczeństwa (np. connection string secrets).
- [ ] Kontrola zmian parametrów serwera — baseline + diff (sprawdzane w CRON/Agent).
