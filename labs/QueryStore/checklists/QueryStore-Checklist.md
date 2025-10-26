# Query Store – Checklista dla DBA

| Zadanie | Opis | Status |
|----------|------|--------|
| 🔧 Włącz Query Store w bazach krytycznych | Ustaw READ_WRITE i parametry retencji | ☐ |
| 📈 Monitoruj DMV `sys.query_store_runtime_stats` | Sprawdzaj zapytania z rosnącym `avg_duration` | ☐ |
| 🧩 Wymuś plan po regresji | Użyj `sp_query_store_force_plan` | ☐ |
| 🧹 Przeglądaj czyszczenie danych QS | Sprawdź `STALE_QUERY_THRESHOLD_DAYS` | ☐ |
| 🧠 Analizuj zapytania z wieloma planami | Wykrywaj niestabilne zapytania | ☐ |
| 💾 Backup danych Query Store | Raz w miesiącu wykonaj kopię tabel QS do osobnej bazy | ☐ |
| 🔍 Po aktualizacji SQL Server – waliduj Query Store | Upewnij się, że tryb READ_WRITE jest aktywny | ☐ |
