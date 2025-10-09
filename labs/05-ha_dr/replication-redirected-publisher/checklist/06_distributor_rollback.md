# Rollback: cofnięcie migracji Dystrybutora (C → A)

> Używaj tylko, jeśli po przeniesieniu dystrybucji na C wystąpił krytyczny problem operacyjny.

## Kroki
1. **Stop na C**
   - Zatrzymaj joby agentów replikacji (Log Reader, Distribution) związane z publikacją.
   - Upewnij się, że brak aktywności replikacyjnej.

2. **Ponownie skonfiguruj dystrybucję na A**
   - Jeśli dystrybucja na A została usunięta: `sp_adddistributor`, `sp_adddistributiondb`, `sp_adddistpublisher`.
   - Odtwórz joby Snapshot/Log Reader/Distribution na A jak przed migracją (lub użyj `sp_addpushsubscription_agent`).

3. **Przekieruj agentów/subskrypcje**
   - Dla **PUSH**: skonfiguruj Distribution Agent na A, wskazujący na subskrybenta B.
   - Dla **PULL**: brak zmian po stronie B (pobiera z C). Jeżeli chcesz wrócić do pełnej topologii na A, przekieruj ponownie wydawcę na B:
     ```sql
     EXEC sp_redirect_publisher
       @original_publisher    = N'ServerA',
       @publisher_db          = N'TwojaBaza',
       @redirected_publisher  = N'ServerA';
     ```

4. **Walidacja**
   - `sp_replmonitorsubscriptionpendingcmds` = 0.
   - `sp_posttracertoken` / `sp_helptracertokenhistory` – akceptowalne opóźnienie.
   - msdb job history bez błędów.

5. **Sprzątanie na C**
   - Usuń joby agentów i dystrybucję na C (`sp_dropdistpublisher`, `sp_dropdistributiondb`, `sp_dropdistributor`), jeśli całkowicie wracasz do stanu „A jako dystrybutor”.
