# Lab 01 – Query Store: baseline → regression → forcing

Cel: pokazać pracę z Query Store – zbieranie baseline, wywołanie regresji (np. sniffing/statystyki), analiza i wymuszenie stabilnego planu.

Kroki:
1) 01_setup.sql – utworzenie bazy i włączenie Query Store (READ_WRITE).
2) 02_workload.sql – generowanie baseline dla przykładowego zapytania.
3) 03_regress.sql – wywołanie regresji (sniffing / UPDATE STATISTICS / parametr).
4) 04_force_plan.sql – identyfikacja i wymuszenie najlepszego planu.
5) 99_cleanup.sql – sprzątanie po labie.
