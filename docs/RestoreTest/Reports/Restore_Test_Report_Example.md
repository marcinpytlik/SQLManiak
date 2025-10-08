# Raport z testu restore – 2025-10-08

**Baza:** DemoDB_Test  
**Typ:** FULL + (opcjonalnie DIFF) + LOG / STOPAT  
**Czas trwania:** (uzupełnij) min

## Kroki
1. Restore FULL (NORECOVERY)
2. Restore DIFF (opcjonalnie, NORECOVERY)
3. Restore LOG (RECOVERY) lub STOPAT
4. DBCC CHECKDB + weryfikacja statusu

## Wynik
- Status: ✅/⚠️/❌
- Uwagi: …

## Artefakty
- CSV: `Reports/Restore_Test_Log.csv`
- XLSX: `Reports/Restore_Test_Log.xlsx`
