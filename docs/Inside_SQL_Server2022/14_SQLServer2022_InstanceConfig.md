# ⚙️ SQL Server 2022 — Parametry instancji (sp_configure)

> Uwaga: wiele opcji „zaawansowanych” widać dopiero po `SHOW ADVANCED OPTIONS = 1`.
> Restart wymagany? Patrz kolumnę **Restart?** – „Tak” oznacza restart usługi SQL Server.

---

## 🔍 Szybki audyt konfiguracji

```sql
-- Włącz podgląd opcji zaawansowanych
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

-- Audyt (czytelny widok z informacją, czy dynamiczne)
SELECT
  name,
  value        AS current_value,
  value_in_use AS in_use,
  is_advanced,
  is_dynamic,                      -- 1 = nie wymaga restartu, 0 = wymaga
  CASE WHEN is_dynamic = 1 THEN 'Nie' ELSE 'Tak' END AS restart_required
FROM sys.configurations
ORDER BY is_advanced, name;
```

---

## 🧠 Pamięć i wydajność

| Parametr | Opis | Baseline / wskazówka | Restart? |
|---|---|---|---|
| **max server memory (MB)** | Górny limit pamięci dla buffera | Ustaw ~70–80% RAM (minus SSRS/SSIS/OS itd.) | Nie |
| **min server memory (MB)** | Dolny limit dla buffera | Często zostawić domyślnie, ustaw w środowiskach dedykowanych | Nie |
| **max degree of parallelism (MAXDOP)** | Maks. stopień równoległości zapytań | Rdzenie NUMA/2 (max 8) – zależnie od CPU i obciążenia | Nie |
| **cost threshold for parallelism** | Próg kosztu dla uruchomienia PARALLEL | 30–100 (zamiast domyślnego 5) | Nie |
| **optimize for ad hoc workloads** | Bufor skompilowanych planów dla single-use | **1 (ON)** w OLTP/ogólnych środowiskach | Nie |
| **lightweight pooling** *(deprecated)* | Tryb fiber | Nie używać | **Tak** |
| **priority boost** *(deprecated)* | Wyższy priorytet procesu | Nie używać | **Tak** |
| **query governor cost limit** | Odrzuca zapytania powyżej kosztu | Zwykle 0 (wył.) | Nie |
| **recovery interval (min)** | Docelowy interwał checkpointów | Zostaw auto; w DW czasem 5–10 | Nie |

---

## 🌐 Sieć i połączenia

| Parametr | Opis | Baseline / wskazówka | Restart? |
|---|---|---|---|
| **remote admin connections** | DAC zdalny (`ADMIN:servername`) | **1 (ON)** w prod | Nie |
| **remote query timeout (s)** | Timeout dla zapytań zdalnych | 0 = bez limitu; często 0 lub 600 | Nie |
| **network packet size (B)** | Rozmiar pakietu TDS | 4096–8192 tylko gdy uzasadnione (duże binaria) | Nie *(dla nowych sesji)* |
| **user connections** | Limit sesji | 0 = auto | Nie |

---

## 🧰 Powierzchnia funkcjonalna (Surface Area)

| Parametr | Opis | Baseline / wskazówka | Restart? |
|---|---|---|---|
| **xp_cmdshell** | Polecenia OS z T-SQL | Wył. (0); włączaj doraźnie i audytuj | Nie |
| **Ole Automation Procedures** | COM/OLE z T-SQL | Wył. (0) | Nie |
| **Ad Hoc Distributed Queries** | OPENROWSET/OPENDATASOURCE | Wył. (0); włącz na czas potrzeby | Nie |
| **clr enabled** | Assemblies CLR | Włącz tylko jeśli używasz; rozważ **CLR strict security** | Nie |
| **scan for startup procs** | Auto-start proc | Zwykle wył. (0) | Nie |
| **contained database authentication** | Contained logins | Włącz, gdy używasz baz contained | Nie |
| **cross db ownership chaining** | Globalny chaining | Zwykle wył. (0); preferuj per-DB | Nie |

---

## 💾 Backup / maintenance

| Parametr | Opis | Baseline / wskazówka | Restart? |
|---|---|---|---|
| **backup compression default** | Domyślna kompresja backupów | **1 (ON)** (o ile CPU/IO pozwala) | Nie |
| **backup checksum default** | Domyślna weryfikacja checksum | Rozważ włączenie w procedurach (sp_configure nie ma globalnego „checksum default”; ustawiaj w skryptach) | – |
| **media retention** | Ile dni trzymać nośniki zgodnie z flagą | Zależnie od polityki (np. 7–30) | Nie |
| **recovery interval** | Patrz wyżej (checkpointy) | Zwykle auto | Nie |
| **two digit year cutoff** | Interpretacja 2-cyfrowych lat | Zostaw 2049 lub polityka firmy | Nie |

---

## 📂 FILESTREAM / zewnętrzne

| Parametr | Opis | Baseline / wskazówka | Restart? |
|---|---|---|---|
| **filestream access level** | Dostęp T-SQL/Win do FILESTREAM | 0/1/2; wymaga też włączenia na serwerze Windows | **Często Tak** |
| **external scripts enabled** | R/Python (Machine Learning) | Włącz tylko gdy potrzebne | Nie *(restart Launchpad)* |

---

## 🕵️‍♂️ Diagnostyka / zdarzenia

| Parametr | Opis | Baseline / wskazówka | Restart? |
|---|---|---|---|
| **default trace enabled** *(deprecated)* | Stary trace serwerowy | Zwykle ON (domyślnie); główny monitoring rób w XE | Nie |
| **blocked process threshold (s)** | Raportowanie blokad > N sekund | 0 = off; np. 5–30 w OLTP (wraz z XE) | Nie |
| **c2 audit mode** *(deprecated)* | Audyt C2 | Nie używać; stosuj **SQL Audit** | **Tak** |

---

## ✅ Bezpieczne ustawianie wartości

```sql
-- Przykład: baseline OLTP
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

EXEC sp_configure 'max server memory (MB)', 49152;        -- 48 GB
EXEC sp_configure 'max degree of parallelism', 8;
EXEC sp_configure 'cost threshold for parallelism', 50;
EXEC sp_configure 'optimize for ad hoc workloads', 1;
EXEC sp_configure 'remote admin connections', 1;
EXEC sp_configure 'backup compression default', 1;

RECONFIGURE;
```

---

## 🧯 Co wymaga restartu?

W skrócie: jeśli `sys.configurations.is_dynamic = 0`, zmiana zwykle wymaga **restartu** usługi SQL Server.  
Typowe przykłady: `lightweight pooling`, `priority boost`, czasem **FILSTREAM** (po stronie serwisu).

```sql
SELECT name, is_dynamic,
  CASE WHEN is_dynamic = 1 THEN 'Nie' ELSE 'Tak' END AS restart_required
FROM sys.configurations
WHERE name IN ('lightweight pooling','priority boost','filestream access level');
```

---

## 📎 Dygresje praktyczne

- **LPIM (Lock Pages In Memory)** nie jest `sp_configure` – ustawiasz to prawami w systemie Windows.  
- **MAXDOP / CTFP** – miej politykę per-serwer i wyjątki per-baza/indeks (hints, scoped config).  
- Zmiany rób **skryptami** i commituj do repo (Infrastructure as Code).  

---

_ostatnia aktualizacja: 2025-09-16_
