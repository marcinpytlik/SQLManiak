
# 10 – ARIES i Page Restore

**Idea:** Model ARIES (Write‑Ahead Logging + Redo/Undo) pozwala na **partial/page restore** po uszkodzeniu strony.

## Demo śladowe (koncepcja – bez psucia stron w produkcji)
```sql
-- Załóżmy backup FULL + sekwencja logów.
-- Przy uszkodzeniu strony:
RESTORE DATABASE DemoDB PAGE = '1:12345' 
FROM DISK = 'DemoDB_full.bak'
WITH NORECOVERY;

RESTORE LOG DemoDB FROM DISK = 'DemoDB_log1.trn' WITH NORECOVERY;
RESTORE LOG DemoDB FROM DISK = 'DemoDB_log2.trn' WITH RECOVERY;
```

## Wnioski
- Page restore skraca RTO przy lokalnym uszkodzeniu danych.
- ARIES gwarantuje spójność przez log redo/undo.
