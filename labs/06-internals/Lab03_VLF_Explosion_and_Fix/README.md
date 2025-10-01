# Lab 03 — VLF Explosion & Fix (Transaction Log Health)

Celem jest **pokazanie eksplozji liczby VLF** (Virtual Log Files) i naprawa:
- jak powstaje setki/tysiące VLF (złe autogrowth, mały inicjalny rozmiar)
- jak to wpływa na **recovery**, **restore** i **truncation**
- jak dobrać rozmiar i growth, aby utrzymać **sensowną liczbę VLF**

> Środowisko: SQL Server 2019/2022 (Developer).

## Plan
1. **Setup**: tworzymy bazę `VLF_Lab` z małym logiem i niekorzystnym autogrowth (np. 1MB).
2. **Reprodukcja**: generujemy dużo logu transakcyjnego (duże inserty, explicit transactions).
3. **Diagnoza**: `sys.dm_db_log_info` (zastępuje `DBCC LOGINFO`) — zliczamy VLF.
4. **Fix**: shrink + regrow w dużych krokach; ustawiamy poprawny growth.
5. **Weryfikacja**: powtarzamy zliczanie VLF i porównujemy czasy operacji.

