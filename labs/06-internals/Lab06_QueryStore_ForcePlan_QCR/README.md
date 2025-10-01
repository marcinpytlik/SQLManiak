# Lab 06 — Query Store: Force Plan & stabilizacja (QCR-like)

Cel:
- Włączyć **Query Store**, uchwycić zapytanie z parametryczną wrażliwością (sniffing), wymusić stabilny plan (`sp_query_store_force_plan`).
- Pokazać porównanie runtime dla „dobrego” i „złego” planu.
- Przykład czyszczenia cache, zmiany rozkładu danych i detekcji regresji.

> Uwaga: Lab zakłada SQL Server 2019/2022. Funkcje typu Query Store hints dostępne w nowszych wersjach — tu używamy podstaw: force/unforce plan.
