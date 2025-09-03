# sqlmaniak

Zbior skryptow, labow i checklist zwiazanych z **SQL Server**.  
Repozytorium prowadzone przez **Marcin Pytlika (aka SQLManiak)** – pasjonata i trenera SQL (MCT)n od wielu lat.

---

## 📂 Struktura repozytorium
- `scripts/` – gotowe skrypty administracyjne i diagnostyczne
- `labs/` – scenariusze do cwiczen
- `checklists/` – listy kontrolne
- `dashboards/` – dashboardy Grafana/InfluxDB
- `docs/` – dodatkowe materialy (PDF, slajdy)
## 📂 Courses

Materiały do oficjalnych kursów Microsoft SQL Server i Azure Data.

- [20761 – Querying Data with Transact-SQL](courses/20761/)  
  Składnia SELECT, JOIN, GROUP BY, podzapytania, funkcje, transakcje.

- [20762 – Developing SQL Databases](courses/20762/)  
  Projektowanie tabel, indeksów, procedur i funkcji. Implementacja logiki w T-SQL.

- [20764 – Administering a SQL Database Infrastructure](courses/20764/)  
  Administracja instancjami SQL Server, bezpieczeństwo, backup/restore, monitorowanie, HA/DR.

- [20765 – Provisioning SQL Databases](courses/20765/)  
  Instalacja i konfiguracja SQL Server, Azure SQL Database, Managed Instance, automatyzacja wdrożeń.

---
### 🎓 Kurs autorski
- [SQL Server 2022 – Instalacja i integracja w różnych środowiskach](courses/SQL2022-Install/)  
  Instalacja SQL Server 2022 w środowiskach Windows (GUI, Core), Linux, Docker oraz integracja z Active Directory i automatyzacja wdrożeń.
- [Administracja bazą danych SQL Server](courses/SQL2022-Admin/)  
  Kompleksowa administracja SQL Server 2016–2022: architektura, bezpieczeństwo, backup/restore, utrzymanie, monitoring i optymalizacja.
- [Optymalizacja bazy danych SQL Server 2022](courses/SQL2022-Optimize/)  
  Zaawansowana optymalizacja SQL Server 2022: diagnostyka, indeksy, partycjonowanie, filegroups, tempdb, parallelism i rozwiązania hybrydowe.
- [Monitoring i wizualizacja danych z wykorzystaniem Grafany – Windows i SQL Server](courses/Grafana-Monitoring/)  
  Monitoring systemów Windows i SQL Server z użyciem Grafany, InfluxDB i Telegraf: dashboardy, alerting, provisioning i bezpieczeństwo.
  ### 🛤️ Ścieżka kursów autorskich SQL Server 2022

[SQL Server 2022 – Instalacja i integracja w różnych środowiskach](courses/SQL2022-Install/) →  
[Administracja bazą danych SQL Server](courses/SQL2022-Admin/) →  
[Optymalizacja bazy danych SQL Server 2022](courses/SQL2022-Optimize/)

Ta ścieżka prowadzi uczestnika od podstaw instalacji i integracji, przez administrację, aż do zaawansowanej optymalizacji SQL Server 2022.


---
## 📚 Dokumentacja

- [Quick Reference Handbook - DMV](docs/dmvs_quick_reference.md)  
  Skondensowana ściąga DMV z podziałem na kategorie + link do skryptu generującego pełną listę.
- [Post-Migration Checklist: SQL Server 2016 → 2022](docs/post_migration_checklist.md)  
  Lista kontrolna kroków po migracji bazy danych: DBCC, statystyki, konfiguracja instancji, Query Store, backupy i testy odzyskiwania.
- [Compatibility Level: SQL Server 2016 → 2022](docs/compatibility_level.md)  
  Wyjaśnienie poziomów zgodności, ich wpływ na optymalizator, strategia testowania oraz dobre praktyki.
## 🎯 Cel
Repozytorium edukacyjne – do nauki, testow i dzielenia sie wiedza.


---

## 📜 Licencja
Licencja [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/deed.en).  
Autor: Marcin (SQLManiak)
