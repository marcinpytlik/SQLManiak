# 📂 SQL Server 2022 – domyślna struktura katalogów (instancja domyślna)

> Dotyczy klasycznej instalacji **Database Engine** (SQL Server 2022, x64) z domyślnymi ustawieniami kreatora, bez zmiany ścieżek.
> Przykłady i nazwy zakładają **instancję domyślną** (`MSSQLSERVER`).

---

## 1) Główne katalogi (Program Files)

Root: `C:\Program Files\Microsoft SQL Server\`

```text
C:\Program Files\Microsoft SQL Server│
├─ 160\Shared\                     # narzędzia wspólne (sqlcmd, bcp, sqldiag, sqldumper)
│
├─ MSSQL16.MSSQLSERVER\            # główny katalog instancji
│   ├─ MSSQL│   │   ├─ Binn\                   # binarki engine (sqlservr.exe, dll)
│   │   ├─ DATA\                   # bazy systemowe i nowe DB (master, model, msdb, tempdb)
│   │   ├─ FTData\                 # dane Full-Text Search
│   │   ├─ ReplData\               # pliki snapshot/replikacja
│   │   ├─ Log\                    # ERRORLOG, SQLAGENT.OUT, logi XE
│   │   └─ Install\                # pliki instalacyjne/konfiguracyjne
│   │
│   └─ Install\                    # pliki setup/instalacji instancji
│
├─ Client SDK\ODBC\                # sterowniki ODBC / biblioteki dla aplikacji
│
├─ Setup Bootstrap\                # logi instalacji/aktualizacji
│   └─ Log\                        # Summary.txt, Detail.txt
│
├─ Tools\Binn\                     # narzędzia klienckie (np. dtexec, profiler – jeśli zainstalowano)
│
└─ ...
```

---

## 2) Katalog systemowy ProgramData (ukryty)

Root: `C:\ProgramData\Microsoft\SQL Server\`

```text
C:\ProgramData\Microsoft\SQL Server│
├─ MSSQL16.MSSQLSERVER\            # konfiguracja instancji, klucze DPAPI, pliki robocze
├─ Licensing\                      # dane licencyjne
├─ Bootstrap\                      # cache setup
└─ Installer\                      # metadane instalatora
```

> **Uwaga:** `ProgramData` jest domyślnie ukryty. Zawiera m.in. pliki niezbędne do rozruchu i ochrony kluczy – nie czyść go pochopnie.

---

## 3) Dodatkowe komponenty (opcjonalne)

### Reporting Services (SSRS) – osobny instalator (2017+)
```text
C:\Program Files\Microsoft SQL Server Reporting Services\SSRS├─ ReportServer└─ RSWebApp```

### Analysis Services (SSAS)
```text
C:\Program Files\Microsoft SQL Server\MSAS16.<INSTANCE>├─ OLAP\Data\                      # bazy SSAS
└─ OLAP\Log\                       # logi SSAS
```

---

## 4) Szybkie zapytania diagnostyczne (T-SQL)

Sprawdzenie **domyślnych ścieżek** danych i logów skonfigurowanych na instancji:

```sql
SELECT
    SERVERPROPERTY('InstanceDefaultDataPath') AS DefaultDataPath,
    SERVERPROPERTY('InstanceDefaultLogPath')  AS DefaultLogPath;
```

Lokalizacja katalogu **ERRORLOG** (aktualna ścieżka pliku z logiem błędów):

```sql
EXEC sys.xp_readerrorlog 0, 1, N'Logging SQL Server messages in file', NULL, NULL, NULL, N'desc';
```

---

## 5) Nazwane instancje i warianty ścieżek

- Dla instancji **nazwanej** (np. `SQLDEV`) katalog instancji będzie miał postać:  
  `C:\Program Files\Microsoft SQL Server\MSSQL16.SQLDEV\...`  
- W środowiskach wielowersyjnych zobaczysz także foldery `150\Shared\` (SQL 2019) itd.  
- Jeśli podczas instalacji zmienisz **Default Data/Log path**, nowe bazy będą trafiały w wskazane lokalizacje (nie wpływa to na już istniejące pliki systemowe).

---

### Podsumowanie

- **Silnik i pliki instancji:** `C:\Program Files\Microsoft SQL Server\MSSQL16.<Instance>\MSSQL\`  
- **Bazy (domyślnie):** `...\DATA\`  
- **Logi SQL/Agent/XE:** `...\Log\`  
- **Narzędzia wspólne:** `C:\Program Files\Microsoft SQL Serverp\Shared\`  
- **Konfiguracja/klucze (ukryte):** `C:\ProgramData\Microsoft\SQL Server\`  
- **Logi instalatora:** `...\Setup Bootstrap\Log\`  

---

_ostatnia aktualizacja: 2025-09-16_
