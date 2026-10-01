# Content Lifecycle

SQLManiak jest rozwijany iteracyjnie. Nie każdy katalog ma tę samą rolę i nie każdy starszy plik jest automatycznie legacy.

## Statusy

### ACTIVE

Aktualna warstwa operacyjna lub aktualny source of truth.

Przykłady:

- `standards/`
- `monitoring/`
- `troubleshooting/`
- `runbooks/`
- `architecture/`
- `RelationalRenaissancePatterns/`

### REFERENCE

Materiał techniczny używany jako źródło wiedzy lub źródło prawdy, ale niebędący głównym punktem nawigacji.

Typowe lokalizacje:

- `docs/`
- wybrane pakiety w `scripts/`
- wybrane pakiety w `tools/`

### LAB

Materiał dydaktyczny, POC lub reprodukcja problemu.

Typowe lokalizacje:

- `labs/`
- wybrane `scripts/*-POC/`
- historyczne materiały szkoleniowe w `labs/training/`

### LEGACY

Materiał zachowany ze względów historycznych lub kompatybilności, którego nie należy traktować jako aktualnego source of truth.

Status LEGACY powinien być jawny w pliku/katalogu. Nie nadajemy go automatycznie tylko dlatego, że materiał jest stary.

### ARCHIVED

Materiał zamknięty i niewspierany, zachowany wyłącznie dla historii.

## Zasada migracji

```text
old content
   |
   +--> nadal poprawny? ------> REFERENCE
   |
   +--> przydatny do ćwiczeń? -> LAB
   |
   +--> zastąpiony? ----------> LEGACY + link do następcy
   |
   +--> nieużywany/zamknięty? -> ARCHIVED
```

## Nagłówek statusu

Przy aktualizacji starego dokumentu można dodać:

```markdown
> **Content status:** REFERENCE  
> **Canonical entry point:** ../../troubleshooting/...  
> **Last reviewed:** YYYY-MM-DD
```

Dla LEGACY:

```markdown
> **Content status:** LEGACY  
> **Superseded by:** ../../standards/...  
> Nie używaj tego dokumentu jako aktualnego standardu operacyjnego.
```

## Nie robimy

- hurtowego przenoszenia setek plików,
- kasowania starych materiałów bez sprawdzenia linków,
- duplikowania treści tylko dlatego, że nowy katalog wygląda czyściej,
- oznaczania całych `docs/`, `scripts/` lub `tools/` jako legacy.

## Cleanup workflow

Przy każdej aktualizacji starego artefaktu:

1. ustal jego status,
2. wskaż canonical entry point,
3. usuń ewidentne duplikaty tylko jeśli ich następca jest jednoznaczny,
4. popraw linki,
5. dodaj go do cross-link mapy, jeśli jest ważnym source of truth,
6. pozostaw historię Git jako historię — nie twórz dodatkowych kopii „archive-copy”.
