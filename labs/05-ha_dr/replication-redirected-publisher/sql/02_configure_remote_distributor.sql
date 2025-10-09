/*
  Konfiguracja zdalnego dystrybutora: C używa A jako dystrybutora.
  Część A (na dystrybutorze) i część C (na nowym wydawcy).
  Użyj właściwych haseł/logowań zgodnie z polityką bezpieczeństwa.
*/

-- === Na Server C ===
-- Wskaż zdalnego dystrybutora (Server A)
-- (Jeśli dystrybucja na A już istnieje, ta operacja tylko dodaje relację z C)
-- UWAGA: uruchom na C
-- EXEC sp_adddistributor @distributor = N'ServerA', @password = N'ZmieńToHasło';

-- === Na Server A (dystrybutor) ===
-- Zarejestruj nowego wydawcę (Server C)
-- UWAGA: uruchom na A
-- EXEC sp_adddistpublisher
--   @publisher = N'ServerC',
--   @distribution_db = N'distribution',
--   @security_mode = 1;   -- lub skonfiguruj dedykowane loginy (SQL Auth)

-- Walidacja (na A)
-- EXEC sp_helpdistpublisher;
