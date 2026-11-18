# Buffer Pool Scan Research Lab — SQL Server 2022

Eksperyment badawczy do artykułu WWSI: **Wpływ równoległego skanowania bufora danych na wydajność operacji administracyjnych w Microsoft SQL Server 2022**.

## Środowisko laboratoryjne
- Windows 11 Pro, Docker Desktop, backend WSL2
- Host: 31,88 GiB RAM; 4 logiczne CPU
- WSL2: memory=20GB; Docker raportuje 19,54 GiB RAM
- Kontener SQL Server 2022 Developer: 16 GiB RAM, 4 CPU, port 127.0.0.1:14334
- Proponowana konfiguracja SQL max server memory: 12288 MB
- Na C: było tylko ~20,5 GiB wolnego; przed generowaniem danych ponownie sprawdzić miejsce.

## Badania
H1 — wpływ liczby buforów na czas skanowania.
H2 — liczba użytych zadań a rozmiar Buffer Pool.
H3 — wpływ równoległości na czas skanu.
H4 — konkurencja współbieżnych skanów.
H5 — zachowanie małych baz w większym Buffer Pool.

**Ograniczenia:** przy 4 schedulerach i ~12 GiB SQL Server może nie uruchomić skanów równoległych w typowych operacjach. Brak zdarzenia buffer_pool_scan_complete nie dowodzi braku skanów. Czas DDL nie jest tożsamy z czasem skanowania.

## Pliki
- `compose.yaml`: dedykowany kontener
- `.env.example`: przykład konfiguracji bez prawdziwych haseł
- `sql/00_preflight.sql`: odczyt parametrów środowiska i metadanych XE
- `protocol/README.md`: protokół badawczy
- `article/README.md`: struktura artykułu
- `results/`: wyniki lokalne (nie commitować dużych plików CSV/XEL)

## Uruchomienie
1. Upewnij się, że pozostałe kontenery są zatrzymane.
2. `Copy-Item .env.example .env` i ustaw silne, unikalne hasło.
3. `docker compose config --quiet`; `docker compose up -d`.
4. Połącz w SSMS z `127.0.0.1,14334` i uruchom `sql/00_preflight.sql`.
5. Po weryfikacji limitów ustaw w SQL `max server memory (MB) = 12288`.
6. Wyniki przechowuj poza repo lub lokalnie w `results/`; do artykułu wprowadzaj zweryfikowane pomiary.

Nie uruchamiać na produkcji; nie używać nieudokumentowanych trace flag ani zmian rejestru w eksperymencie podstawowym.
