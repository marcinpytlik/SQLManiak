# Release & Versioning Policy

SQLManiak DBA Library jest repozytorium wiedzy, narzędzi i materiałów operacyjnych, dlatego versioning nie jest traktowany identycznie jak versioning biblioteki aplikacyjnej.

## Default model

Głównym źródłem aktualnego stanu jest:

```text
master
```

Każdy merge do `master` powinien pozostawić repo w stanie:

- przechodzącym CI,
- spójnym dokumentacyjnie,
- gotowym do użycia.

## Releases

GitHub Release / tag tworzymy dla istotnych punktów stabilizacyjnych, np.:

- duży pakiet nowych runbooków,
- nowa wersja monitoring stack,
- zakończenie większego cyklu migracyjnego,
- istotna wersja narzędzia,
- szkoleniowy/laboratoryjny milestone.

Nie tworzymy release dla każdej korekty Markdown.

## Version format

Dla całej DBA Library preferowany jest kalendarzowy format:

```text
YYYY.MM
YYYY.MM.N
```

Przykłady:

```text
2026.09
2026.09.1
2026.10
```

Znaczenie:

- `YYYY.MM` — główny milestone w danym miesiącu,
- `YYYY.MM.N` — kolejna stabilizowana wersja w tym samym miesiącu.

## Narzędzia z własnym lifecycle

Narzędzie może mieć własny Semantic Versioning, jeżeli ma stabilny interfejs lub jest używane niezależnie.

Przykład:

```text
DBMigrationPack v2.1.0
Zabbix template v1.4.0
```

Wtedy versioning narzędzia jest niezależny od release całej DBA Library.

## Breaking change

Za breaking change uznajemy m.in.:

- usunięcie lub zmianę ścieżki publicznie linkowanego artefaktu,
- zmianę parametrów skryptu/narzędzia bez kompatybilności,
- zmianę formatu danych wejściowych/wyjściowych,
- zastąpienie standardu bez migration note,
- usunięcie runbooka bez wskazania następcy.

Breaking change powinien zawierać:

- uzasadnienie,
- migration note,
- nowy canonical entry point,
- aktualizację cross-linków.

## Deprecation

Preferowany model:

```text
ACTIVE
→ REFERENCE / LEGACY
→ replacement link
→ okres przejściowy
→ ARCHIVED
```

Nie usuwamy od razu publicznie linkowanych materiałów, jeśli można zachować redirect/canonical pointer w dokumentacji.

## Release checklist

Przed release:

- [ ] `master` jest zielony.
- [ ] Validate DBA Library przechodzi.
- [ ] Validate dashboard JSON przechodzi.
- [ ] Inventory jest aktualny.
- [ ] Cross-link map jest aktualny.
- [ ] Nie ma znanych krytycznych broken links.
- [ ] Breaking changes mają migration notes.
- [ ] Release notes opisują najważniejsze zmiany.

## Release notes

Release notes powinny grupować zmiany według:

```text
Architecture
Standards
Monitoring
Troubleshooting
Runbooks
Tools
Labs
Governance
Fixes
Breaking changes
```
