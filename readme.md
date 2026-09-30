# SQLManiak DBA Library

Praktyczna, rozwijana iteracyjnie biblioteka wiedzy dla administratorów i architektów **Microsoft SQL Server**.

Repozytorium prowadzone przez **Marcina Pytlika (SQLManiak)** – Microsoft Certified Trainer, DBA i architekta SQL Server.

> Nie jest to tylko zbiór skryptów. Celem repozytorium jest połączenie wiedzy, procedur, narzędzi, checklist, laboratoriów i gotowych materiałów operacyjnych w jedno miejsce, w którym wiadomo **gdzie szukać rozwiązania**.

## 🗺️ Mapa DBA Library

- [DBA Library Cross-Link Map](docs/DBA-LIBRARY-MAP.md) — domenowe przejście Architecture → Standards → Monitoring → Troubleshooting → Runbooks.
- [Content Lifecycle](docs/CONTENT-LIFECYCLE.md) — ACTIVE / REFERENCE / LAB / LEGACY / ARCHIVED.
- [Legacy / Reference Cleanup](docs/LEGACY-CLEANUP.md) — status porządkowania starszych obszarów repo.
- [DBA Library Inventory](docs/DBA-LIBRARY-INVENTORY.md) — automatycznie generowany katalog kanonicznych artefaktów.

---

## 🧭 Zacznij od problemu

### 🔎 Muszę zdiagnozować problem

- [Troubleshooting](troubleshooting/)
- [Skrypty diagnostyczne](scripts/)
- [Dashboardy i monitoring](dashboards/)
- [Checklisty](checklists/)

Obszary, które rozwijamy:

- blocking i deadlocki
- CPU
- memory
- I/O
- TempDB
- Query Store
- waits
- replication
- backup/restore
- problemy HA/DR

### 🛠️ Muszę wykonać operację DBA

- [Runbooki](runbooks/)
- [Standardy](standards/)
- [Checklisty](checklists/)
- [Skrypty](scripts/)

Docelowo każdy powtarzalny proces powinien mieć:

1. opis celu,
2. prerequisites,
3. procedurę,
4. walidację,
5. rollback,
6. skrypty pomocnicze.

### 📊 Muszę monitorować środowisko

- [Monitoring](monitoring/)
- [Dashboardy Grafana](dashboards/)
- [Skrypty diagnostyczne](scripts/)

### 🏗️ Muszę zaprojektować rozwiązanie

- [Architecture](architecture/)
- [Relational Renaissance Patterns](RelationalRenaissancePatterns/)

### 🧪 Chcę przećwiczyć temat

- [Labs](labs/)
- [Courses](courses/)
- [Relational Renaissance Patterns](RelationalRenaissancePatterns/)

---

# 📚 Główne obszary DBA Library

## Standards

[standards/](standards/)

Standardy techniczne i zasady utrzymania środowiska, m.in.:

- SQL Server build
- backup & restore
- security
- maintenance
- patching
- monitoring
- capacity

Standard odpowiada na pytanie:

> **Jak powinniśmy to robić?**

---

## Runbooks

[runbooks/](runbooks/)

Procedury wykonywania powtarzalnych operacji administracyjnych.

Runbook odpowiada na pytanie:

> **Jak wykonać tę operację bezpiecznie i powtarzalnie?**

---

## Troubleshooting

[troubleshooting/](troubleshooting/)

Procedury diagnostyczne oparte na symptomach, obserwacjach, hipotezach i walidacji.

Troubleshooting odpowiada na pytanie:

> **Co sprawdzić, kiedy coś nie działa albo działa wolno?**

---

## Scripts

[scripts/](scripts/)

Gotowe skrypty T-SQL, PowerShell i narzędzia automatyzacyjne.

Skrypt nie powinien być samotnym artefaktem — tam, gdzie to możliwe, powinien być powiązany z runbookiem, troubleshootingiem albo standardem.

---

## Monitoring

[monitoring/](monitoring/)

Materiały dotyczące:

- alertów,
- baseline,
- collectorów,
- metryk,
- progów,
- obserwowalności SQL Server.

Istniejące dashboardy znajdują się również w [dashboards/](dashboards/).

---

## Architecture

[architecture/](architecture/)

Miejsce na:

- ADR,
- diagramy,
- reference architectures,
- decyzje HA/DR,
- deployment patterns,
- dokumentację integracji.

---

## Relational Renaissance Patterns

[RelationalRenaissancePatterns/](RelationalRenaissancePatterns/)

Biblioteka wzorców projektowania relacyjnych baz danych.

Struktura każdego wzorca jest oparta na prostym standardzie:

```text
README.md
NOTES.md
demo.sql
```

Ten model traktujemy jako wzorzec dla dalszej rozbudowy SQLManiak DBA Library.

---

## Labs

[labs/](labs/)

Scenariusze laboratoryjne i środowiska demonstracyjne.

---

## Courses

[courses/](courses/)

Materiały do kursów Microsoft oraz kursów autorskich SQLManiak.

### Kursy Microsoft

- [20761 – Querying Data with Transact-SQL](courses/20761/)
- [20762 – Developing SQL Databases](courses/20762/)
- [20764 – Administering a SQL Database Infrastructure](courses/20764/)
- [20765 – Provisioning SQL Databases](courses/20765/)

### Kursy autorskie

- [SQL Server 2022 – Instalacja i integracja w różnych środowiskach](courses/SQL2022-install/)
- [Administracja bazą danych SQL Server](courses/SQL2022-admin/)
- [Optymalizacja bazy danych SQL Server 2022](courses/SQL2022-Optimize/)
- [Monitoring i wizualizacja danych z wykorzystaniem Grafany – Windows i SQL Server](courses/Grafana-Monitoring/)

---

## Documentation

[docs/](docs/)

Dodatkowe materiały referencyjne.

Wybrane dokumenty:

- [Quick Reference Handbook - DMV](docs/Inside_SQL_Server2022_Databases/dmvs_quick_reference.md)
- [Post-Migration Checklist: SQL Server 2016 → 2022](docs/post_migration_checklist.md)
- [Compatibility Level: SQL Server 2016 → 2022](docs/compatibility_level.md)

---

# 🧩 Standard artefaktu

W nowych materiałach preferowany jest układ:

```text
topic/
├── README.md
├── NOTES.md
└── scripts/
```

Dla procedur operacyjnych:

```text
operation/
├── README.md
├── PRECHECK.md
├── RUNBOOK.md
├── VALIDATION.md
├── ROLLBACK.md
└── scripts/
```

Nie każdy temat potrzebuje wszystkich plików. Struktura ma pomagać, a nie tworzyć dokumentację dla samej dokumentacji.

---

# 📝 Templates

[templates/](templates/)

Szablony służą do zachowania spójnego sposobu dokumentowania:

- troubleshooting,
- runbooków,
- ADR,
- standardów technicznych.

---

# ✅ Quality / Governance

Walidatory DBA Library znajdują się w [tools/dba-library-quality](tools/dba-library-quality/).

PR-y do `master` mogą automatycznie sprawdzać:

- strukturę Standards / Monitoring / Runbooks / ADR,
- wewnętrzne linki Markdown w kanonicznych warstwach,
- aktualność wygenerowanego inventory,
- niezależnie: poprawność JSON dashboardów Grafana.

---

# 🔄 Zasady rozwoju repozytorium

SQLManiak DBA Library rozwijamy iteracyjnie.

1. **Jedno źródło prawdy** – unikamy duplikowania tej samej dokumentacji.
2. **Version control** – kod, runbooki i dokumentacja techniczna żyją w Git.
3. **Context before code** – skrypt powinien mieć opis zastosowania.
4. **Validation matters** – procedura nie kończy się na wykonaniu polecenia; musi istnieć sposób potwierdzenia rezultatu.
5. **Rollback when possible** – zmiany produkcyjne powinny mieć opis drogi powrotnej.
6. **Lifecycle instead of chaos** – treść ma jawny status: ACTIVE, REFERENCE, LAB, LEGACY lub ARCHIVED.
7. **Canonical entry point** – starszy poprawny materiał może pozostać na miejscu, ale powinien wskazywać aktualną warstwę wejściową.
8. **Strangler approach** – nie reorganizujemy całego repo jednorazowo. Nowe materiały powstają według nowego modelu, a stare są klasyfikowane/migrowane przy okazji ich aktualizacji.

---

# 🎯 Cel

Celem repozytorium jest stworzenie praktycznej, publicznej **SQL Server DBA Library**:

- do codziennej pracy DBA,
- do diagnostyki,
- do automatyzacji,
- do nauki,
- do prowadzenia szkoleń,
- do dokumentowania dobrych praktyk,
- do budowania powtarzalnych procedur operacyjnych.

---

## 📜 Licencja

Licencja [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/deed.en).

Autor: **Marcin Pytlik (SQLManiak)**
