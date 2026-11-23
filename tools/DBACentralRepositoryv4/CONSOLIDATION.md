# Konsolidacja dawnych pakietów DBA

**Jeden docelowy katalog w `tools`: `DBACentralRepositoryv4`.**

## Foldery źródłowe do likwidacji po migracji

| Legacy | Docelowy moduł | Status |
|---|---|---|
| `tools/DBADaillyPack` | `modules/health/` | Do przeniesienia i testów |
| `tools/DBAInventoryPack` | `modules/inventory/` | Do przeniesienia i testów |
| `tools/DBAInvestigatePack` | `modules/investigate/` | Do przeniesienia i testów |
| `tools/DBAMigrationPack` | `modules/migration/` | Nie znaleziono katalogu pod podaną nazwą |

**Nie usuwaj źródeł przed kompletną migracją.** Podczas inspekcji potwierdzono obecność pierwszych trzech katalogów, ale bez pełnego spisu plików nie można bezpiecznie potwierdzić kompletności przenosin.

## Zakres

- `modules/inventory`: instancje, konfiguracja, wszystkie bazy, pliki, joby, loginy, użytkownicy, uprawnienia, HA.
- `modules/health`: Daily Health Check i źródła danych dla precheck/postcheck.
- `modules/investigate`: diagnostyka incydentów DBA.
- `modules/migration`: narzędzia migracyjne.
- `modules/patching`: planowanie, wykonanie i audyt.
- `sql`: baza DBACentralRepositoryv4 i skrypty instalacji.
- `grafana`: dashboardy po ukończeniu części kolektorów (bez implementacji na tym etapie).

## Warunki usunięcia

1. Ustalić pełną listę plików i zależności.
2. Przenieść skrypty bez utraty historii przez `git mv` w lokalnym checkout lub równoważną operację zachowującą kompletne treści.
3. Uaktualnić ścieżki w jobach, harmonogramach i dokumentacji.
4. Zweryfikować uruchamianie kolektorów, importy, dry-run i raporty.
5. Usunąć pierwotne katalogi na gałęzi roboczej i dopiero po przeglądzie PR scalać do master.

Uwaga: pozostałe, niezwiązane narzędzia w `tools` nie podlegają usunięciu.
