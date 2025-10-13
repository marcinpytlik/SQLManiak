# Checklist: PRE (A→B→C)

- [ ] Backupy pełne baz na A (DynamicsAX, DynamicsAX_model, ReportServer*, ReportServerTempDB*).
- [ ] Backup klucza szyfrowania SSRS na A.
- [ ] Eksport konfiguracji AX BI (adres serwera SSRS, konta).
- [ ] Przygotowane ścieżki danych/logów na B (NTFS, uprawnienia).
- [ ] Konto usługowe SSRS (C) utworzone, hasło znane.
- [ ] Dostęp sieciowy między C ↔ B (TDS 1433/instancja) i ULR do portalu C.
- [ ] Zapasowe miejsce na backupy i logi.
