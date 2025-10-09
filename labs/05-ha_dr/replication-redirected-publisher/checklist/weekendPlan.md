# Plan migracji replikacji (weekend)

## Krok 1 (sobota)
**Przenieś Publishera A → C** i zostaw **Dystrybutora na A** jako zdalnego dla C.  

## Krok 2 (niedziela)
Gdy wszystko „gra”, **przenieś rolę Dystrybutora A → C**.

---

## Dlaczego tak ?

**Mniej ryzyka w oknie cięcia.**  
Najbardziej wrażliwy moment to finalny LOG + `KEEP_REPLICATION` + `sp_redirect_publisher`.  
Nie mieszamy wtedy jeszcze w dystrybucji i jobach.

**Prostsza diagnostyka.**  
Jeśli po cutoverze coś nie gra, wracamy redirectem na A w minutę.  
Gdyby równocześnie przenosić dystrybutora, „punktów awarii” jest więcej.

**Brak reinitu na B.**  
`sp_redirect_publisher` + `allow_initialize_from_backup` zachowuje subskrypcję.

- Masz **push** i chcesz na spokojnie odtworzyć Distribution Agent na C.  
- Chcesz najpierw zobaczyć 12–24 h stabilnej pracy (brak błędów 14151/14157, brak zaległych komend).  
- Zależy mi na **prostym rollbacku** w razie problemów po deployu.

---

## Kryteria „zielonego światła” przed migracją dystrybutora

- `sp_replmonitorsubscriptionpendingcmds` = **0** (lub stabilnie nisko).  
- `sp_helptracertokenhistory` – akceptowalna i powtarzalna latencja.  
- Brak błędów agentów w `msdb.dbo.sysjobhistory` przez kilka cykli.  
- Healthcheck (`msdb.dbo.ReplLatencyLog`) nie pokazuje tokenów „In-Transit” wiszących godzinami.

---

## Mini-plan na weekend

### Sobota
1. **Pre-Flight + DryRun.**  
2. **Cutover:** stop agentów na A → finalny LOG → restore na C z `KEEP_REPLICATION` → `sp_redirect_publisher` na B → walidacja → start agentów.  
3. **Włącz healthcheck job** (co 10 min) i alerty 14151/14157.

### Niedziela (opcjonalnie)
1. Jeśli stabilnie: uruchom `20.Move-Distributor.ps1`  
   (konfiguracja dystrybucji na C → joby → walidacja → cleanup na A).  
2. Jeszcze raz tracer tokens i raport z `ReplLatencyLog`.

Moja rekomendacja: **wariant dwuetapowy** – przewidywalność wygrywa z heroizmem :)

---

