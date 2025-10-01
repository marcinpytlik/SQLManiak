# Checklist — Architektura VLDB
- [ ] Model danych przeanalizowany pod partycjonowanie (kolumna klucza zakresu: `LoadDate` / `BusinessDate` / `IdRange`).
- [ ] Podział na **filegroupy**: `FG_HOT` (READ WRITE), `FG_WARM` (READ WRITE), `FG_COLD` (READ ONLY), `FG_ARCHIVE` (READ ONLY).
- [ ] Każda duża tabela w osobnym **partition scheme** i **function**.
- [ ] Tempdb na szybkim NVMe, oddzielny wolumen, odpowiednia liczba plików.
- [ ] Oddzielne filegroupy dla dużych indeksów kolumnowych (jeśli używasz).
- [ ] Uzgodnione RPO/RTO i przepływy DR (AG/Log Shipping/SAN snapshots).
