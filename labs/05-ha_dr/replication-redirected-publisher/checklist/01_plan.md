# Plan & precheck (A → C, B zostaje)

- [ ] Zidentyfikowane publikacje/artykuły i typy agentów (push/pull).
- [ ] Spisane konta/login SID dla repl_* oraz właścicieli jobów (patrz `sql/00_inventory.sql`).
- [ ] `allow_initialize_from_backup = true` ustawione (`sql/01_enable_init_from_backup.sql`).
- [ ] C skonfigurowane, by używać A jako dystrybutora (`sql/02_configure_remote_distributor.sql`).
- [ ] Próbne backupy i verifyonly (`sql/03_backup_commands.sql`).
- [ ] Plan okna cięcia: godzina, komunikacja do użytkowników, blokada ruchu.
- [ ] Dostęp przywracania na C (ścieżki, uprawnienia do plików).
- [ ] Zweryfikowane `@@SERVERNAME` na A i C (brak różnic z nazwą wystąpienia).
