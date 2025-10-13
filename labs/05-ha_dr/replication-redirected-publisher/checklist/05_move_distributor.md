# Migracja Dystrybutora A → C (po cutover Publishera)

## Precheck (A)
- [ ] `10_prechecks_undistributed_cmds.sql`: undistributed cmds = 0.
- [ ] Zatrzymane joby agentów na A (Log Reader, Distribution) dla tej publikacji.
- [ ] Potwierdzony brak ruchu na A (Publisher jest już na C).

## Konfiguracja dystrybucji na C
- [ ] `11_configure_distribution_on_C.sql`: `sp_adddistributor`, `sp_adddistributiondb`, `sp_adddistpublisher`.
- [ ] Katalog snapshotu dostępny i z odpowiednimi uprawnieniami serwisów.

## Joby na C
- [ ] `12_snapshot_logreader_jobs_on_C.sql`: Snapshot Agent + sprawdzenie Log Reader.
- [ ] DLA PUSH: `13_recreate_push_agents_on_C.sql` — odtworzenie Distribution Agentów.
- [ ] DLA PULL: brak akcji (subskrybenci pociągną z C).

## Walidacja
- [ ] `15_validation_after_move.sql`: tracer token latency i undistributed cmds.
- [ ] msdb job history bez błędów.

## Sprzątanie na A
- [ ] `14_cleanup_distribution_on_A.sql`: `sp_dropdistpublisher`, `sp_dropdistributiondb`, `sp_dropdistributor`.
- [ ] Archiwizacja starych jobów/logów.
