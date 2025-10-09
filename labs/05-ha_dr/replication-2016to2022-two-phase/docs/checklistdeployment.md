# ✅ Migracja replikacji SQL 2016 → SQL 2022 (pełna checklist A4)

> Środowisko: A/B (SQL 2016) → C/D (SQL 2022)
> 
> Data: ___________      Operator: ___________      Zatwierdził: ___________

---

## 🔹 FAZA 1 – Migracja subskrybenta (B → D)

☐ 01. Zweryfikuj wersje SQL (A=2016, D=2022)  
☐ 02. Sprawdź konfigurację publikacji (`sp_helppublication`, `sp_helpdistributor`)  
☐ 03. Włącz `allow_initialize_from_backup = true` na publikacji  
☐ 04. Wykonaj FULL + LOG backup bazy na A (`\\A\Backups`)  
☐ 05. Przywróć bazę na D z backupu (FULL + LOG)  
☐ 06. Utwórz **PULL** subscription na D z init-from-backup  
☐ 07. Sprawdź status subskrypcji (`sp_helptracertokenhistory`)  
☐ 08. Zweryfikuj, że D otrzymuje dane (zmiana w tabeli testowej)  
☐ 09. Przełącz raporty/aplikacje z B → D  
☐ 10. Zamroź B (read-only / offline)

📍 *Stan po fazie 1: A=Publisher+Distributor (2016), D=Subscriber (2022)*

---

## 🔹 FAZA 2 – Migracja Publishera + Dystrybutora (A → C)

☐ 11. Zatrzymaj ruch do bazy na A  
☐ 12. Zatrzymaj agenty Log Reader / Distribution  
☐ 13. Wykonaj finalny LOG backup na A (`TwojaBaza_p2_FINAL_LOG.trn`)  
☐ 14. Przywróć FULL + LOG + FINAL_LOG na C z `KEEP_REPLICATION, RECOVERY`  
☐ 15. Uruchom `sp_vupgrade_replication` na C  
☐ 16. Skonfiguruj dystrybucję lokalną na C (`sp_adddistributor`, `sp_adddistpublisher`, `sp_adddistributiondb`)  
☐ 17. Zweryfikuj joby agentów (Log Reader, Distribution, Snapshot)  
☐ 18. Jeśli subskrypcja to **PULL**: wykonaj `sp_redirect_publisher` na D (A→C)  
☐ 19. Jeśli subskrypcja to **PUSH**: odtwórz Distribution Agent na C  
☐ 20. Uruchom agentów i obserwuj tracer tokeny  
☐ 21. Sprawdź brak błędów 14151/14157 w msdb  
☐ 22. Upewnij się, że `sp_replmonitorsubscriptionpendingcmds=0`  
☐ 23. Po 12–24h stabilnej pracy usuń dystrybucję z A (`sp_dropdistributor`)

📍 *Stan po fazie 2: C=Publisher+Distributor (2022), D=Subscriber (2022)*

---

## 🔹 MONITORING (po fazie 2)

☐ 24. Skonfiguruj operatora `ReplOps` + alerty 14151/14157  
☐ 25. Podłącz alerty do jobów replikacyjnych  
☐ 26. Utwórz job „Repl Latency Probe” (co 10 min)  
☐ 27. Zweryfikuj wpisy w `msdb.dbo.ReplLatencyLog`  
☐ 28. Uruchom mini-dashboard (`sql_common/12_dashboard_dmv.sql`)  
☐ 29. Przejrzyj błędy jobów w msdb (`sysjobhistory`)  
☐ 30. Zweryfikuj raport z tracer tokenów i opóźnienia

---

## 🔹 COMPATIBILITY LEVEL (po stabilizacji)

☐ 31. Sprawdź obecny poziom (`sys.databases`) – powinno być 130  
☐ 32. Uruchom `sql_common/20_prep_after_restore.sql` (CHECKDB, STATs, Query Store)  
☐ 33. Podnieś D (Subscriber) do 160 (`21_upgrade_to_160.sql`)  
☐ 34. Podnieś C (Publisher) do 160  
☐ 35. (opcjonalnie) podnieś `distribution` do 160  
☐ 36. Obserwuj Query Store – brak regresji planów  
☐ 37. W razie regresji – włącz `LEGACY_CARDINALITY_ESTIMATION=ON` lub PSP=OFF  
☐ 38. Po weryfikacji wyłącz bezpieczniki (wróć do ON/OFF właściwie)  
☐ 39. Zrób snapshot konfiguracji (`sp_helpdistributiondb`, `sp_helppublication`)  
☐ 40. Zarchiwizuj repo i raport operacji (pełen log migracji)

---

## 🟢 STATUS KOŃCOWY

☐ Replikacja działa na C/D (2022)  
☐ Alerty aktywne (14151/14157)  
☐ Healthcheck job działa co 10 minut  
☐ Compatibility level = 160 na wszystkich bazach  
☐ Query Store RW, brak regresji  
☐ Wszystkie backupy i logi zarchiwizowane  
☐ Dokumentacja repo w wersji końcowej

Podpis operatora: ________________________  
Podpis weryfikującego: _____________________  
Data zakończenia: _________________________
