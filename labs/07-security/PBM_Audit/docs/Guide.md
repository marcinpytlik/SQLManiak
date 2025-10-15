# PBM + Audit: Minimum Viable Drift Control

Celem jest szybkie uzyskanie dwóch rzeczy:
- **Audit**: *kto/co/kiedy* — np. `ALTER DATABASE`.
- **PBM (Policy-Based Management)**: *co odjechało* — wykrywanie dryfu ustawień bazy/instancji.

## Kroki

### 1) Audit do pliku
- Utwórz Server Audit zapisujący na dysk .
- Włącz grupy akcji: `DATABASE_CHANGE_GROUP`, `SERVER_OBJECT_CHANGE_GROUP`, `SERVER_OPERATION_GROUP`.
- Zweryfikuj, że powstają pliki `.sqlaudit` w docelowym katalogu.

### 2) PBM — warunek i polityka
- Facet `Database` — pilnujemy: `PAGE_VERIFY = CHECKSUM`, `AUTO_CLOSE = OFF`, `AUTO_SHRINK = OFF`, `RECOVERY = FULL`.
- Polityka w trybie **On Schedule: Log Only** i Job co 5 minut.

### 3) Raporty
- Widok z `sys.fn_get_audit_file(...)` pokazuje, kto wykonał zmiany.
- Historia PBM w `msdb.dbo.syspolicy_*` — co nie przeszło.
- Zapytanie korelujące oba źródła w ~15-min oknie czasowym.

### 4) Dostosowanie
- Dodaj kolejne facety/opcje do PBM (np. AutoCreateStatistics, ANSI ustawienia).
- Do audytu dołóż grupy `DATABASE_OBJECT_CHANGE_GROUP`, `SCHEMA_OBJECT_CHANGE_GROUP` jeśli potrzebne.
- Zamiast tylko logować, możesz użyć **On change: prevent** (ostrożnie!).

> Ten pakiet nie wprowadza DDL triggerów ręcznie — PBM zrobi to sam, gdy wybierzesz tryb prevent dla obsługiwanych facetów.
