# Okno cięcia (A → C)

1. [ ] Wstrzymaj ruch do bazy na A (aplikacje/lockdown).
2. [ ] Zatrzymaj **Log Reader** i **Distribution Agent** dla tej publikacji (`sql/04_cutover_stop_agents_and_final_log.sql`).
3. [ ] Wykonaj finalny **LOG BACKUP** (A).
4. [ ] Skopiuj plik(a) LOG na C.
5. [ ] Na C odtwórz FULL + LOG(i) z NORECOVERY, a finalny LOG **WITH KEEP_REPLICATION, RECOVERY** (`sql/05_restore_on_C_keep_replication.sql`).
6. [ ] Na B wykonaj `sp_redirect_publisher` A→C (`sql/06_redirect_on_B.sql`).
7. [ ] Na C uruchom `sp_validate_redirected_publisher` i sprawdź publikacje (`sql/07_validate_on_C.sql`).
8. [ ] Uruchom agenty (`sql/08_start_agents.sql`) i potwierdź przepływ.
9. [ ] Testowy INSERT/UPDATE -> pojawia się na B.
