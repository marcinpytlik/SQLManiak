# Cluster-Aware Updating (CAU) – szkic operacyjny

## Po co?
Automatyzuje aktualizacje Windows, wykonując je sekwencyjnie na węzłach klastra, z „drain roles” i restartami, bez ręcznej akrobatyki.

## Tryby
- **Self-updating** – mechanizm wewnątrz klastra (rzadziej używany).
- **Remote-updating** – z hosta zarządzającego (najczęściej).

## Kroki operacyjne (Remote-updating)
1. Sprawdź zdrowie klastra (`Test-Cluster`, Event Viewer).
2. `Suspend-ClusterNode -Name NODEX -Drain` – przeniesie role na inne węzły.
3. Zainstaluj aktualizacje, zrestartuj NODEX.
4. `Resume-ClusterNode -Name NODEX`.
5. Powtórz dla kolejnych węzłów.
6. Na końcu przywróć preferowaną lokalizację roli SQL (Preferred Owners).

## Uwagi dla SQL
- Przed startem: powiadomienia/okno serwisowe.
- Po każdym restarcie węzła: szybki smoke test SQL (VNN, logowanie, Agenta, podstawowe zapytania).
