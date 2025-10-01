# Lab 04 — ADR vs klasyczne recovery (szybkie UNDO, PVS)

Cel labu:
- Porównać zachowanie **rollback** i recovery z **ADR (Accelerated Database Recovery)** włączonym i wyłączonym.
- Zmierzyć czas ROLLBACK długiej transakcji.
- Podejrzeć **Persisted Version Store (PVS)** i jego statystyki.

> Wymagania: SQL Server 2019/2022 Developer. Uprawnienia sysadmin.

## Plan
1. **Setup**: dwie bazy — `ADR_On_DB` (ADR ON) i `ADR_Off_DB` (ADR OFF) z identyczną tabelą i danymi.
2. **Long Txn**: odpalamy dużą transakcję `DELETE` i robimy **ROLLBACK** — mierzymy czas w obu bazach.
3. **PVS**: oglądamy `sys.dm_tran_persistent_version_store_stats` i rozmiary PVS.
4. **Wniosek**: z ADR rollback jest szybki (czas ≈ stały, niezależny od liczby operacji), bez ADR czas ≈ proporcjonalny do rozmiaru transakcji.

## Jak uruchomić
- `01_setup.sql` → tworzy bazy i dane.
- `02_long_txn_rollback_ADR_ON.sql` → test w bazie z ADR ON.
- `03_long_txn_rollback_ADR_OFF.sql` → test w bazie z ADR OFF.
- `04_pvs_stats.sql` → statystyki PVS i podsumowanie.

> Uwaga: nie „crashujemy” instancji; mierzymy **czas ROLLBACK** — to bezpieczny proxy dla efektu ADR.
