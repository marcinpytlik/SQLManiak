# Checklist — Utrzymanie/Statystyki/Indeksy
- [ ] **Incremental statistics** włączone dla partycjonowanych indeksów.
- [ ] Aktualizacje statystyk z kontrolą próbkowania (np. `WITH SAMPLE 3 PERCENT` na gigantach).
- [ ] Używamy **reorganize** na partycjach; **rebuild** tylko na wybranych partycjach.
- [ ] **Filtered stats** dla silnie skośnych rozkładów (skew).
- [ ] Eliminacja partycji w zapytaniach (SARG warunki po kolumnie partycjonującej).
- [ ] Retencja i rozmiar **Query Store** dostosowane (limit MB, cleaning policy).
