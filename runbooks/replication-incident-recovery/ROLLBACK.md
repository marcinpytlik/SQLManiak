# Transactional Replication Incident Recovery — ROLLBACK

## Kiedy
- restart agenta zwiększa błędy
- zmiana schema szkodzi
- reinit nie może się zakończyć

## Procedura
1. Zatrzymaj agent powodujący dalsze szkody.
2. Cofnij odwracalną zmianę config/schema.
3. Jeśli rozpoczęto reinit, kontynuuj zgodnie z planem reseed zamiast ufać staremu stanowi.

## Walidacja rollback
- brak dalszej złej propagacji
- stan subscription jednoznaczny
- plan dalszego recovery zapisany
