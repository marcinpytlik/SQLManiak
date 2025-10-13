/*
  Bezpieczniki „awaryjne” na poziomie bazy (do włączenia/wyłączenia natychmiast).
  Używaj doraźnie, potem diagnozuj Query Store i porządkuj statystyki/indeksy.
*/
USE [TwojaBaza]; -- PODMIEŃ

-- Powrót do starego estymatora CE (zachowując 160)
ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = ON;  -- lub OFF

-- Wyłączenie PSP (jeśli podejrzewasz regresję z param. sensitive plans)
ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = OFF; -- lub ON
