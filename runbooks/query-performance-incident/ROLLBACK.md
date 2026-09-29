# Query Performance Incident — ROLLBACK

## Kiedy
- nowy plan szkodzi innym parametrom
- index zwiększa koszt writes nieakceptowalnie
- hint/forcing powoduje regresję

## Procedura
1. Cofnij index/hint/forcing zgodnie z planem.
2. Przywróć poprzedni plan, jeśli jest udokumentowany jako bezpieczny.
3. Ponownie zmierz reprezentatywne parametry.

## Walidacja
- zapytanie wróciło do znanego stabilnego stanu
- brak nowych regresji
- evidence zachowane
