# SQLManiak — DBACentralRepositoryv4

Jedno centralne repozytorium: **Inventory → Patch Planner → Patch Execution → Patch Audit → Grafana**.

> Status: **foundation / development**. Ta gałąź zawiera fundament bazy i planowania, nie kompletny gotowy mechanizm produkcyjnego patchowania. **Nie uruchamiaj patchowania automatycznie.**

## Cele

- Pełna inwentaryzacja konfiguracji instancji, baz, plików, tempdb, obiektów, SQL Agent, loginów, użytkowników, ról i uprawnień, linked servers, HA/FCI/AG, wersji i ustawień.
- Historia skanów, wykrywanie zmian i źródło prawdy dla wszystkich narzędzi DBA.
- Harmonogram patchowania grup FRIDAY/SUNDAY/MANUAL/EXCLUDED z wyjątkami, zależnościami i zatwierdzeniami.
- Kontrolowana obsługa FCI, precheck / postcheck, job snapshots oraz audyt zmian.
- Widoki raportowe dla przyszłych dashboardów Grafana (bez dashboardów w tej fazie).

## Dlaczego v4 nie jest kopią v3

W `scripts/DBACentralRepository_v3` wiele skryptów zawiera na sztywno `USE [DBACentralRepository]`. Ich ślepe uruchomienie w v4 mogłoby zmodyfikować **starą bazę**. Dlatego v4 ma osobny katalog, bazę i skrypty. Migracja istniejących modułów jest zadaniem kontrolowanym, z testami kompatybilności.

## Instalacja fundamentu (wyłącznie LAB)

1. Uruchom `sql/00_Bootstrap.sql` na docelowym serwerze SQL (SQL Server 2016+).
2. Uruchom `sql/01_Inventory_Core.sql`.
3. Uruchom `sql/02_Patch_Planner.sql`.
4. Uruchom `sql/03_Reports.sql`.
5. W bazie `DBACentralRepositoryv4` sprawdź `SELECT * FROM report.vPatchPlan;`.
6. Zarejestruj instancje w `inventory.Instance`, topologię HA w `inventory.Host` / `inventory.InstanceHost` i przypisania w `patch.TargetAssignment`; nie zapisuj haseł.
7. Przetestuj planowanie na danych LAB bez wykonywania patchów.

Nie stosuj istniejących skryptów v3 przez zamianę nazwy bazy w ciemno.

## Co dostarcza obecny commit

- Osobna baza `DBACentralRepositoryv4` i domenowe schematy.
- Rejestr instancji, hostów, powiązań instancja–host, skanów i typowanych snapshotów inwentaryzacji.
- Patch groups, windows, przypisania, planowane operacje, jawne zatwierdzenia, zdarzenia i fazy PRE/POST.
- Read-only widok raportowy; **brak automatycznego wykonywania aktualizacji**.

## Reuse / source of truth

| Zakres | Źródło istniejące w SQLManiak | Kierunek v4 |
|---|---|---|
| Inventory / compliance | `tools/DBAInventoryPack` | Wspólny kolektor i mapowanie |
| Repozytorium / SQL collector | `scripts/DBACentralRepository_v3` | Przenieść i przetestować moduły, bez nadpisywania v3 |
| PRE/POST | `scripts/DBACentralRepository_v3/19_Create_Patch_Audit_Lifecycle.sql` | Adaptacja do v4 |
| SQL Agent jobs | `scripts/sql-agent-work-calendar-patching` | Wywołania kontrolowane, snapshot i restore |
| Operacje patchingowe | `runbooks/sql-server-patching` | Orkiestracja zgodna z runbookiem |
| Health checks | `tools/SQLManiakDailyHealthCheck/v1.7` | Adapter do wyników pre/post |
| Grafana | `scripts/DBACentralRepository_v3/grafana` | Docelowo dashboard v4 |

## Bezpieczeństwo

- Domyślnie read-only; wykonanie patchowania wyłącznie po zatwierdzeniu i kontrolach.
- FCI: planować zmianę na poziomie klastra/całego zestawu ról, inwentaryzować hosty i właścicieli, wykrywać kolizje. Operacje failover wykonywać jawnie.
- Patching nie jest rollbackiem SQL do poprzedniej CU: rollback strategy to osobny zatwierdzony runbook.
- Brak haseł i sekretów w repozytorium.
- Nie zbierać definicji modułów T-SQL i sekretów jako domyślnej części inventory.
- Wszystkie czasy przechowywać w UTC, okna interpretować w jawnej strefie.
- Każda zmiana: change ID, tożsamość wykonawcy, audit trail.

## Plan ukończenia projektu

- [x] Struktura v4, odrębna baza, inventory core i patch planner.
- [x] Pierwsza implementacja rozszerzonego kolektora (obiekty, indeksy, statystyki, schematy, metadane HA) — **wymaga testów LAB**.
- [x] Pierwsza implementacja snapshot diff + zapisu SqlBulkCopy — **wymaga testów LAB**.
- [ ] Polityka uprawnień, bezpieczna retencja, testy wydajności i HA Windows LAB.
- [ ] Import i uzgodnienie aktualnych przypisań piątek / niedziela.
- [ ] Integracja patch lifecycle v3 i SQL Agent patching window.
- [ ] Orkiestrator PowerShell: dry-run, approval gate, PRE/POST, FCI node sequence, health validation, resumption.
- [ ] Testy LAB (standalone i FCI), instrukcja wdrożeniowa produkcyjna.
- [ ] Grafana dashboardy i alerty (oddzielny etap wizualny).

## Nazewnictwo

Folder: `tools/DBACentralRepositoryv4/`; baza: `DBACentralRepositoryv4`; schematy `inventory`, `patch`, `audit`, `report`, `config`; wszystkie istniejące projekty pozostają bez zmian.

## Inventory v4.1 — rozszerzony skan

Po wykonaniu pięciu skryptów SQL z `sql/` (w tym `04_Extended_Inventory_And_Diff.sql`) uruchom `docker/Test-Inventory.ps1 -Persist`. Po drugim kompletnym skanie z pokryciem kategorii powstają zdarzenia w `inventory.ChangeEvent`. Instrukcja testów: [EXTENDED_INVENTORY.md](modules/inventory/EXTENDED_INVENTORY.md).
