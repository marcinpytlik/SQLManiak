# 📂 SQL Server 2022 — Parametry na poziomie bazy danych

---

## 🔍 Szybki audyt parametrów bazy

```sql
-- Lista wszystkich opcji bazy danych
SELECT name, value, value_for_secondary, description, is_advanced
FROM sys.database_scoped_configurations;

-- Opcje bazy danych
SELECT name, is_auto_create_stats_on, is_auto_update_stats_on,
       is_auto_shrink_on, is_auto_close_on, is_read_only,
       recovery_model_desc, containment_desc
FROM sys.databases
WHERE name = 'TwojaBaza';
```

---

## 🧠 Statystyki i optymalizator

| Parametr | Opis | Rekomendacja | Restart DB? |
|---|---|---|---|
| **AUTO_CREATE_STATISTICS** | Automatyczne tworzenie statystyk | ON (większość OLTP/DW) | Nie |
| **AUTO_UPDATE_STATISTICS** | Automatyczne aktualizowanie statystyk | ON (default), dla dużych DW OFF + manual jobs | Nie |
| **AUTO_UPDATE_STATISTICS_ASYNC** | Aktualizacja statystyk w tle | Rozważ ON w OLTP z dużym ruchem | Nie |

---

## 📊 Wzrost plików / zarządzanie przestrzenią

| Parametr | Opis | Rekomendacja | Restart DB? |
|---|---|---|---|
| **AUTO_SHRINK** | Automatyczny shrink bazy | ZAWSZE OFF | Nie |
| **AUTO_CLOSE** | Zamykaj bazę przy braku użycia | ZAWSZE OFF (tylko w dev/test) | Nie |
| **AUTO_CREATE_FILEGROUPS** | Auto-tworzenie FG (dot. FILESTREAM/FG) | Rzadko ON | Nie |

---

## 🔒 Bezpieczeństwo i spójność

| Parametr | Opis | Rekomendacja | Restart DB? |
|---|---|---|---|
| **ALLOW_SNAPSHOT_ISOLATION** | Tryb snapshot isolation | ON w OLTP, gdy potrzebne | Nie |
| **READ_COMMITTED_SNAPSHOT** | RCSI (row versioning dla Read Committed) | Włącz w większości OLTP (eliminuje blokady read) | **Tak** (rollback bazy) |
| **PAGE_VERIFY** | Algorytm weryfikacji stron | CHECKSUM | Nie |
| **TRUSTWORTHY** | Zezwala na dostęp do zasobów systemowych | ZAWSZE OFF (chyba że wymuszone) | Nie |
| **CONTAINMENT** | Czy baza contained | None/Partial | Nie |
| **ENCRYPTION** | Transparent Data Encryption (TDE) | ON, gdy wymagana polityką | Nie |

---

## 🔁 Replikacja i dostępność

| Parametr | Opis | Rekomendacja | Restart DB? |
|---|---|---|---|
| **DATABASE_MIRRORING** | Tryb mirroringu (deprecated) | W nowych wdrożeniach AlwaysOn zamiast | Tak |
| **HADR** | AlwaysOn Availability Groups | Włącza obsługę AG | Nie |
| **PARTNER / WITNESS** | Ustawienia mirroringu | Deprecated | Tak |

---

## 🚀 Query Store (od SQL 2016+)

| Parametr | Opis | Rekomendacja | Restart DB? |
|---|---|---|---|
| **QUERY_STORE = ON/OFF** | Włącza Query Store | ON dla wszystkich baz prod | Nie |
| **OPERATION_MODE** | Read Write / Read Only | RW w prod, RO np. w DR | Nie |
| **CLEANUP_POLICY** | Retencja danych (dni) | 30–90 w OLTP | Nie |
| **INTERVAL_LENGTH_MINUTES** | Interwał agregacji | 15–60 min | Nie |
| **MAX_STORAGE_SIZE_MB** | Limit rozmiaru | zależny od bazy (1000–5000 MB) | Nie |

---

## 💾 Recovery model i log

| Parametr | Opis | Rekomendacja | Restart DB? |
|---|---|---|---|
| **RECOVERY_MODEL** | SIMPLE / FULL / BULK_LOGGED | Prod: FULL; Dev/test: SIMPLE | Nie |
| **TARGET_RECOVERY_TIME** | Dftr. czas recovery (ms) | np. 60 sek. | Nie |
| **DELAYED_DURABILITY** | Możliwość „lazy commit” | Zwykle DISABLED | Nie |

---

## 🌐 Opcje dostępu

| Parametr | Opis | Rekomendacja | Restart DB? |
|---|---|---|---|
| **MULTI_USER / SINGLE_USER / RESTRICTED_USER** | Dostęp do bazy | MULTI_USER w prod | Tak (zmiana trybu) |
| **READ_ONLY** | Baza tylko do odczytu | Dev/archiwa | Tak |
| **ONLINE / OFFLINE** | Stan bazy | Prod = ONLINE | Tak |

---

## 📎 Przykład zmiany opcji

```sql
ALTER DATABASE [MojaBaza]
SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;

ALTER DATABASE [MojaBaza]
SET QUERY_STORE = ON;
```

---

## 🔎 Podsumowanie

- Na poziomie **instancji** → konfiguracja globalna (`sp_configure`).  
- Na poziomie **bazy danych** → tryby pracy, statystyki, Query Store, recovery, bezpieczeństwo.  
- Niektóre zmiany wymagają **rollback bazy** (np. RCSI, READ_COMMITTED_SNAPSHOT).  
- Dobre praktyki: trzymaj **baseline konfiguracji per-baza** w repo.  

---

_ostatnia aktualizacja: 2025-09-16_
