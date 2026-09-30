# SQL Server Patching — PRECHECK

## Kontekst

Zapisz:

```text
Server / instance:
Database / component:
Incident or change window:
Business impact:
Owner:
Expected result:
```

## Sprawdzenia przed wykonaniem

1. Potwierdź maintenance window i plan kolejności node/instancji.
2. Zrób baseline wersji/build.
3. Zweryfikuj backupy system/user databases.
4. W module patchingowym wykonaj Preview jobów do wyłączenia.
5. Zidentyfikuj joby, których nie wolno wyłączać automatycznie.
6. Dla FCI potwierdź stan klastra/quorum i passive node.

## Evidence before

- build przed zmianą
- lista/snapshot jobów
- stan usług
- stan HA
- czas początku okna

## Stop conditions

- brak aktualnych backupów zgodnych z polityką
- klaster/AG jest niestabilny
- Preview jobów pokazuje nieakceptowalne wyłączenia
- brak planu rollback
