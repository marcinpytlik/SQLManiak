# 🔍 Co się dzieje w trakcie BACKUP DATABASE

## 📍 Punkt startu
- SQL Server robi tzw. **fuzzy checkpoint** → zapisuje spójny stan startowy.
- Od tego momentu wszystkie zmiany są „śledzone” w **logu transakcyjnym**.

---

## 📂 Kopiowanie danych
- Backup czyta **strony danych (8 KB)** z plików MDF/NDF.
- To nie jest kopia offline — backup idzie w swoim tempie, a użytkownicy mogą nadal modyfikować dane.

---

## 📒 Log transakcyjny w tle
- Wszystkie zmiany w trakcie backupu trafiają do logu.
- Na końcu backup **dogrywa fragment logu** (od startu do końca backupu).
- Dzięki temu baza przywrócona jest spójna na moment zakończenia backupu.

---

## 🔒 Co jest blokowane?
- Backup **nie blokuje** `INSERT/UPDATE/DELETE` ani `SELECT`.
- Backup **nie blokuje** większości `ALTER DATABASE` (np. zmiany `COMPATIBILITY_LEVEL`).
- Wyjątki: operacje silnie ingerujące w strukturę bazy (np. `ALTER DATABASE ... ADD FILE`) mogą chwilowo poczekać.

---

## 🖊️ Operacje DML (INSERT/UPDATE/DELETE)
- Są **dozwolone** podczas backupu.
- Transakcje zapisują się w logu, a backup dogrywa je do `.bak` na końcu.

---

## 📏 Wpływ na log transakcyjny
- Log **musi zostać zachowany** do końca backupu, żeby baza była spójna.
- Efekt: **log nie może być skracany** dopóki backup trwa.
- Przy długich backupach log może urosnąć mocniej niż zwykle.

---

## ⚡ ALTER DATABASE podczas backupu
- Większość poleceń działa (np. zmiana `COMPATIBILITY LEVEL`).
- Polecenia typu `SET OFFLINE` → zakończą się błędem, bo baza jest używana.
- Zmiana `RECOVERY MODEL` działa, ale wpływa na kolejne log backupy.

---

## 🧩 Podsumowanie
- **INSERT/UPDATE/DELETE** → działają normalnie.  
- **SELECT** → pełna dostępność.  
- **ALTER DATABASE** → większość działa, ale nie wszystkie (np. OFFLINE, ADD FILE mogą się nie udać).  
- **LOG** → nie jest skracany aż do końca backupu, więc może rosnąć.  

👉 Backup to nie „stop-klatka” całej bazy, tylko proces:  
**czytanie stron danych + dogranie logu** → spójna kopia w `.bak`.

---

## 🔄 Diagram – krok po kroku

```
 ┌──────────────────┐
 │ Start BACKUP      │
 │ BACKUP DATABASE   │
 └───────┬──────────┘
         │
         ▼
 ┌──────────────────┐
 │ Fuzzy Checkpoint │
 │ zapis spójnego   │
 │ punktu startu    │
 └───────┬──────────┘
         │
         ▼
 ┌──────────────────┐
 │ Czytanie stron   │
 │ danych (MDF/NDF) │
 │ sekwencyjnie     │
 └───────┬──────────┘
         │
         ▼
 ┌──────────────────┐
 │ W tle użytkownik │
 │ wykonuje DML     │
 │ (INSERT/UPDATE)  │
 └───────┬──────────┘
         │
         ▼
 ┌──────────────────┐
 │ Log rejestruje   │
 │ wszystkie zmiany │
 │ (nie skraca się) │
 └───────┬──────────┘
         │
         ▼
 ┌──────────────────┐
 │ Dogranie logu do │
 │ pliku .bak – aby │
 │ baza była spójna │
 │ na koniec backupu│
 └───────┬──────────┘
         │
         ▼
 ┌──────────────────┐
 │ Koniec BACKUP    │
 │ (spójna kopia DB)│
 └──────────────────┘
```

---

## 🧪 Scenariusz testowy – AdventureWorks2022

- Recovery model: **FULL**  
- Backup FULL: start 10:00, koniec 11:00  
- Odtwarzanie o 12:00  

**Pytanie 1:** Czy `INSERT` o 10:30 znajdzie się w backupie?  
✔ Tak — bo log z 10:00–11:00 jest dograny na końcu backupu.  

**Pytanie 2:** Czy muszę od razu zrobić backup logu?  
✔ Nie musisz od razu, ale:  
- Backup FULL nie czyści logu.  
- Jeśli nie robisz backupów logów, plik `.ldf` będzie rósł.  
- W praktyce robimy log backup co 15–60 minut.  

---
