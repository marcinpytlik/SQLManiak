# Lab 08 — Parameter Sensitive Plan Optimization (SQL Server 2022)

Cel:
- Pokazać **Parameter Sensitive Plan (PSP) Optimization** – różne plany dla różnych „kubełków” kardynalności (np. rzadki vs gęsty parametr).
- Porównać z klasycznym sniffingiem i zadziałaniem wymuszania planu.
- Zajrzeć do DMVs/Query Store, żeby zobaczyć warianty planów.

## Wymagania
- SQL Server 2022 (compat 160), `PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON`.
