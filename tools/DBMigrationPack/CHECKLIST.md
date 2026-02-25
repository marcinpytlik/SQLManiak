# Checklist migracji SQL Server (MD) — precheck → backup/restore → postcheck

> Cel: migracja baz z `source` na `destination` bez niespodzianek po restore.  
> Pipeline: **precheck-migration → Invoke-SqlBackupRestore → postcheck-migration**  
> Założenie: baza na **source** zostaje w `READ_ONLY` i jest usuwana po **7 dniach**.

---

## Day -7 — Start (pierwszy precheck „na sucho”)

### Uruchomienia
- [ ] Uruchom **precheck (dry-run)** (bez `READ_ONLY`):
  ```powershell
  .\precheck-migration.ps1 -ConfigPath .\config.json
  ```

### Weryfikacja wyników (log precheck)
- [ ] Każda baza: `PRECHECK OK` (ONLINE, brak stanów nietypowych).
- [ ] **Space check** na DEST:
  - [ ] `SPACE OK | DATA`
  - [ ] `SPACE OK | LOG`
- [ ] **Feature snapshot**: przejrzyj `HINT` oraz `DEST CHECK FAIL/WARN`.
- [ ] Zanotuj rzeczy „poza DB”, które trzeba migrować osobno:
  - [ ] loginy / mapowania SID (orphaned users)
  - [ ] SQL Agent jobs, operators, alerts
  - [ ] linked servers / credentials / proxies
  - [ ] certyfikaty/klucze z `master` (jeśli TDE/crypto)

### Decyzje / plan
- [ ] Ustal okno migracji (start/koniec, kontakt on-call).
- [ ] Potwierdź plan rollback (7 dni read_only na source).

---

## Day -6 — Remediacja środowiska DEST (komponenty i konfiguracja)

### Komponenty instancji / usługi
- [ ] Jeśli `DEST CHECK FAIL` dla Full-Text → doinstaluj Full-Text na DEST.
- [ ] Jeśli `DEST CHECK FAIL` dla FILESTREAM/FileTable → skonfiguruj FILESTREAM na DEST.
- [ ] Jeśli `DEST CHECK FAIL` dla CLR → włącz `clr enabled` (jeśli wymagane i zaakceptowane przez security).
- [ ] Upewnij się, że **SQL Server Agent** na DEST działa (zwłaszcza przy CDC).

### Storage / miejsce
- [ ] Dodaj brakujące miejsce na wolumenach `dataDir` / `logDir` (wg precheck).
- [ ] Potwierdź, że docelowe ścieżki istnieją:
  - [ ] `restoreOptions.dataDir`
  - [ ] `restoreOptions.logDir`

### Sieć / dostęp
- [ ] Upewnij się, że DEST ma dostęp do `backuppath` (UNC) **w kontekście konta usługi SQL Server**.
- [ ] Sprawdź przepustowość / okno backupów na fileserver.

---

## Day -5 — Bezpieczeństwo / kryptografia / zależności

- [ ] Jeśli baza ma **TDE**:
  - [ ] przenieś certyfikat + private key z `master` na DEST (i przetestuj na kopii).
- [ ] Jeśli używane są certyfikaty/klucze w DB:
  - [ ] potwierdź, czy wymagają dodatkowych obiektów na poziomie serwera.
- [ ] Zbierz listę logins powiązanych z bazą:
  - [ ] dla najważniejszych aplikacji: potwierdź, że loginy istnieją na DEST.

---

## Day -3 — Próba generalna (test restore / test logowania)

- [ ] Wykonaj próbny restore na środowisku testowym lub na osobnej bazie na DEST (jeśli to możliwe).
- [ ] Uruchom `postcheck-migration` w trybie report-only:
  ```powershell
  .\postcheck-migration.ps1 -ConfigPath .\config.json
  ```
- [ ] Sprawdź dostęp aplikacji (testowe połączenie / smoke tests).

---

## Day -1 — Freeze i gotowość do Day 0

- [ ] Potwierdź, że nikt nie planuje zmian w schemacie/konfiguracji.
- [ ] Ustal komunikat do użytkowników (okno niedostępności).
- [ ] Upewnij się, że logi trafiają do `logOptions.logDir` i masz je pod ręką.
- [ ] Ostatni precheck „na sucho” dla spokoju:
  ```powershell
  .\precheck-migration.ps1 -ConfigPath .\config.json
  ```

---

## Day 0 — Migracja (cutover)

### Krok 1: Precheck + READ_ONLY na SOURCE
- [ ] Uruchom precheck z przełączeniem na `READ_ONLY`:
  ```powershell
  .\precheck-migration.ps1 -ConfigPath .\config.json -SetReadOnly
  ```
- [ ] Zweryfikuj w logu:
  - [ ] brak `SPACE FAIL`
  - [ ] `READ_ONLY OK` dla każdej bazy

### Krok 2: Backup + Restore
- [ ] Uruchom migrację (backup/restore):
  ```powershell
  .\Invoke-SqlBackupRestore.ps1 -ConfigPath .\config.json
  ```
- [ ] Zweryfikuj:
  - [ ] backup powstał w `backuppath`
  - [ ] restore zakończył się sukcesem dla każdej bazy
  - [ ] ścieżki `MOVE` są zgodne z `dataDir`/`logDir`

### Krok 3: Postcheck na DEST (ustawienia + weryfikacja)
- [ ] Uruchom postcheck **z ApplyChanges**:
  ```powershell
  .\postcheck-migration.ps1 -ConfigPath .\config.json -ApplyChanges
  ```
- [ ] Zweryfikuj w logu:
  - [ ] `compatibility_level = 160`
  - [ ] Query Store: `actual_state_desc` = READ_WRITE, limit ~2GB
  - [ ] Baza: `READ_WRITE`
  - [ ] **Orphaned users**: przejrzyj wpisy `ORPHANS FOUND` (jeśli są)

### Krok 4: Smoke tests / walidacja biznesowa
- [ ] Połączenie aplikacji do DEST (test logowania).
- [ ] 2–3 kluczowe transakcje / raporty działają.
- [ ] Monitor: błędy w logach aplikacji, SQL errorlog, joby.

---

## Day +1 do Day +7 — Okres obserwacji (source zostaje READ_ONLY)

Codziennie:
- [ ] Sprawdź błędy aplikacji (logowanie/permissions).
- [ ] Sprawdź SQL Agent joby (czy coś nie failing).
- [ ] Monitoruj Query Store / wydajność (regresje planów, waits).
- [ ] Jeśli były `ORPHANS FOUND`:
  - [ ] zdecyduj: naprawiać czy zostawić (w zależności od tego, kto i jak się loguje).

---

## Day +7 — Zamknięcie migracji (cleanup)

- [ ] Potwierdź z biznesem: brak rollback / wszystko działa.
- [ ] Usuń bazy na SOURCE (zgodnie z polityką):
  - [ ] ręcznie albo przez zaplanowany job (`schedule-drop-after-7days.ps1`)
- [ ] Zarchiwizuj logi i dokumentację zmiany.
- [ ] Spisz krótkie „lessons learned” (co poprawić w następnym runie).

---
