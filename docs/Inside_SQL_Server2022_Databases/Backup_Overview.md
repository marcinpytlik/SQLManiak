# 📦 Backupy w SQL Server – ogólny obraz

## 🔹 Typy backupów

### 1. Full Backup
- Kopiuje **całą bazę danych** (wszystkie pliki danych).
- Zawiera fragment logu transakcyjnego → baza po odtworzeniu jest spójna na moment końca backupu.
- Jest **bazą odniesienia** dla backupów różnicowych (DIFF).

### 2. Differential Backup
- Kopiuje **tylko te extenty**, które zmieniły się od ostatniego FULL.
- Wykorzystuje mapę **DCM (Differential Change Map)**.
- Z czasem DIFF rośnie, bo zawiera wszystkie zmiany od FULL (a nie od ostatniego DIFF).

### 3. Log Backup
- Zawiera **sekwencję wpisów z logu transakcyjnego** od ostatniego backupu logu.
- Umożliwia **punkt-in-time recovery** (RESTORE DATABASE + RESTORE LOG ... STOPAT).
- Wymaga **Recovery Model: FULL lub BULK_LOGGED**.
- W modelu SIMPLE log backup nie jest możliwy.

### 4. File / Filegroup Backup
- Backup wybranych plików lub grup plików.
- Przydatne w dużych bazach z podziałem na filegroupy.

### 5. Partial Backup
- Backup tylko części bazy (np. **primary + read-write filegroups**).
- Przydatne w scenariuszach archiwalnych / testowych.

---

## 🔹 Parametry i opcje BACKUP DATABASE

- **COPY_ONLY**
  - Tworzy backup, który **nie wpływa na chain** (łańcuch LSN).
  - Full COPY_ONLY → nie resetuje punktu różnicowego (DIFF dalej wie, że bazą odniesienia jest poprzedni pełny „normalny” backup).
  - Log COPY_ONLY → nie „czyści” logu (nie zmienia chaina log backupów).

- **INIT / NOINIT**
  - `INIT` – nadpisuje plik backupu.
  - `NOINIT` – dopisuje nowy set backupu do istniejącego pliku.

- **COMPRESSION**
  - Kompresuje strony danych, zmniejsza rozmiar i często przyspiesza backup.

- **CHECKSUM**
  - Backup weryfikuje checksummy stron danych.
  - Dodatkowa ochrona przed zapisem uszkodzonych stron do pliku `.bak`.

- **STATS = N**
  - Pokazuje progres backupu co N procent.

---

## 🔹 Recovery Model a backupy

### SIMPLE
- Nie można robić **log backupów**.
- Log jest automatycznie skracany po checkpointach.
- Możesz używać tylko FULL + DIFF.

### FULL
- Pełna historia transakcji.
- Wymaga **regularnych log backupów**, bo inaczej log rośnie w nieskończoność.
- Umożliwia punkt-in-time recovery.

### BULK_LOGGED
- Prawie jak FULL, ale operacje bulk (np. `BULK INSERT`, `SELECT INTO`) są logowane minimalnie.
- Backup logu może być większy, bo obejmuje wtedy całe extenty zmodyfikowane przez bulk.
- Też umożliwia punkt-in-time recovery (z wyjątkiem okna z bulk-logged).

---

## 🔹 Jak łączą się backupy

Przykład łańcucha:

```
FULL (niedziela 00:00)
   |
   +--> DIFF (poniedziałek 00:00)
   +--> DIFF (wtorek 00:00)
   |
   +--> LOG (poniedziałek 01:00)
   +--> LOG (poniedziałek 02:00)
   ...
```

- Aby odtworzyć bazę do wtorku 02:00:
  1. Przywróć FULL.
  2. Przywróć ostatni DIFF (wtorek 00:00).
  3. Przywróć kolejne LOG backupy aż do 02:00.

---

## 🔹 Ogólne zasady praktyczne

- **Pełny backup** raz dziennie (np. w nocy).
- **Różnicowe** co kilka godzin (np. co 6h).
- **Log backupy** często (np. co 15 min), żeby:
  - ograniczyć rozrost pliku `.ldf`,
  - zminimalizować utratę danych w razie awarii.
- Regularnie testuj restore (`RESTORE VERIFYONLY` ≠ test restore!).
- W dużych bazach rozważ file/filegroup backupy.

---
