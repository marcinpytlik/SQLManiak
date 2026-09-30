# Standard: Database Files & Autogrowth

## Purpose

Ujednolicić layout, rozmiary początkowe i autogrowth plików danych/logu oraz ograniczyć przypadkowe wzrosty i problemy capacity.

## Scope

Wszystkie bazy użytkownika oraz odpowiednie pliki systemowe.

## Requirements

### Required

- Autogrowth jest ustawiony w MB, nie w procentach.
- Rozmiar początkowy odpowiada przewidywanemu użyciu.
- Dane i log mają osobne wartości autogrowth.
- Log jest pre-size’owany.
- Preferowany jest jeden plik logu.
- Cykliczny shrink logu jest zabroniony.
- Monitorowany jest `log_reuse_wait_desc`.
- Pliki danych/logu mają udokumentowaną lokalizację.
- `AUTO_SHRINK = OFF`.
- `AUTO_CLOSE = OFF`.
- `PAGE_VERIFY = CHECKSUM`.

### Recommended

Punkty startowe z obecnego standardu repo:

```text
Mała baza    : Data 256 MB  / Log 128 MB
Średnia baza : Data 1024 MB / Log 512 MB
Duża baza    : Data 4096 MB / Log 1024 MB
```

Nie są to wartości obowiązkowe — mają zostać dopasowane do workloadu i storage.

### Not allowed

- Autogrowth procentowy.
- Regularny shrink danych/logu jako maintenance.
- Dodawanie wielu plików logu jako sposób na problem z growth/performance.
- Przypadkowe pliki/filegroupy bez udokumentowanego celu.
- Pozostawienie małych domyślnych rozmiarów dla dużej bazy produkcyjnej.

## Default configuration

Nazewnictwo:

```text
<Database>_Data.mdf
<Database>_Data01.ndf
<Database>_Log.ldf
```

Dodatkowe filegroupy tylko z uzasadnieniem.

## Exceptions

Wyjątek musi opisywać:

- powód,
- layout,
- storage,
- przewidywany wzrost,
- ownera,
- datę przeglądu.

## Validation

- `sys.master_files`,
- growth settings,
- weekly autogrowth review,
- wolne miejsce plików i filesystemu,
- monitoring filegroup/log capacity.

## Ownership

DBA / właściciel platformy.

## Review cycle

- miesięcznie w audycie konfiguracji,
- po gwałtownym wzroście bazy,
- po migracji/storage change.

## References

- [Database standards/checklists](../../scripts/DBACentralRepository_v3/SQL_Server_Databases_13_Checklists_16_Standards.md)
- [Database Configuration](../../docs/Inside_SQL_Server2022/15_SQLServer2022_DatabaseConfig.md)
- [I/O Troubleshooting](../../troubleshooting/io/)
