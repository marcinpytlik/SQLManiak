# Backup / Restore / Recovery — PRECHECK

## 1. Zdefiniuj cel recovery

Zapisz przed rozpoczęciem:

```text
Source database:
Target instance:
Target database:
Required restore point:
Required RPO:
Required RTO:
Recovery model:
```

## 2. Sprawdź recovery model

Dla `SIMPLE` oczekiwany chain to zwykle:

```text
FULL
+
optional DIFF
```

Dla `FULL`:

```text
FULL
+
optional DIFF
+
LOG chain
```

Jeżeli wymagany jest point-in-time restore, przygotuj wartość `STOPAT`.

## 3. Zweryfikuj dostępne backupy

W `msdb` sprawdź co najmniej:

- `msdb.dbo.backupset`,
- `msdb.dbo.backupmediafamily`.

Zapisz:

- backup type,
- backup start/finish,
- first/last LSN,
- differential base,
- physical device.

Nie wybieraj DIFF wyłącznie dlatego, że jest najnowszy — musi odpowiadać właściwemu FULL.

## 4. Zweryfikuj pliki i dostęp

Potwierdź:

- pliki backupów istnieją,
- SQL Server ma do nich dostęp,
- zasób sieciowy jest dostępny, jeśli dotyczy,
- dla encrypted backup dostępny jest wymagany materiał kryptograficzny.

## 5. Sprawdź layout i miejsce

Użyj:

- [Estimate Restore Space](../../scripts/t-sql/backup/restoresize.sql)

Skrypt korzysta z `RESTORE FILELISTONLY` i pozwala ocenić wymaganą przestrzeń z marginesem.

Przy restore na inną instancję przygotuj mapowanie `WITH MOVE`.

## 6. VERIFYONLY

Wykonaj `RESTORE VERIFYONLY` dla wybranego media set.

Pamiętaj:

> `RESTORE VERIFYONLY` nie zastępuje realnego restore test.

## 7. Stop conditions

Przerwij przed restore, jeżeli:

- brakuje elementu wymaganego chaina,
- backup jest niedostępny,
- nie ma wystarczającej przestrzeni,
- nie można ustalić właściwego restore point,
- wymagany encrypted backup nie może zostać odszyfrowany.
