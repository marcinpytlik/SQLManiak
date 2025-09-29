# 🔄 Zmiana Recovery Model a backupy

## 🔹 Z FULL → BULK_LOGGED
- Łańcuch backupów logu **nadal jest spójny** (LSN chain się nie zrywa).
- Log backupy nadal działają, ale:
  - operacje typu `BULK INSERT`, `SELECT INTO`, `CREATE INDEX` mogą być **minimalnie logowane**,
  - przy kolejnym **log backupie** te operacje powodują, że do log backupu trafiają całe extenty (większy rozmiar).
- Punkt-in-time recovery: nadal możliwe (STOPAT działa), z wyjątkiem **okresu, w którym wykonano bulk-logged operacje** → tam odtwarzasz tylko do końca backupu logu, nie do środka.

## 🔹 Z BULK_LOGGED → FULL
- Zmiana nie zrywa chainu.
- Następne log backupy znów są w pełni logowane.
- Punkt-in-time recovery wraca w pełnym zakresie.

## 🔹 Z FULL / BULK_LOGGED → SIMPLE
- **Tu jest inaczej**: chain backupów logu się **zrywa**.
- Wszystkie transakcje w logu są oznaczone jako skonsumowane → kolejnego log backupu zrobić się nie da, dopóki nie zrobisz nowego FULL.
- Harmonogram log backupów traci sens (będą błędy: *"BACKUP LOG cannot be performed because there is no current database backup."*).

## 🔹 Z SIMPLE → FULL / BULK_LOGGED
- Chain backupów logu zaczyna się **od nowa**.
- Trzeba zrobić **pełny backup** → dopiero potem kolejne log backupy mogą być poprawnie odtwarzane.

---

## 📅 Wpływ na harmonogramy backupów

1. **FULL ↔ BULK_LOGGED**
   - Harmonogram backupów logu działa normalnie.
   - Ryzyko: nagły wzrost rozmiaru backupu logu przy operacjach bulk-logged.
   - Punkt-in-time ograniczone tylko w okresie bulk.

2. **Zmiana na SIMPLE**
   - Harmonogram backupów logu przestaje działać (błędy).
   - Potrzebna zmiana strategii: tylko FULL + DIFF.
   - Po powrocie na FULL → konieczny nowy FULL backup.

---

## 🧩 Praktyczne wskazówki

- Monitoruj `sys.databases.recovery_model_desc` → wykryjesz nieplanowane zmiany.
- Ustaw alert na zmianę Recovery Model w środowisku produkcyjnym.
- Jeśli używasz BULK_LOGGED na potrzeby dużych operacji:
  - zaplanuj powrót do FULL,
  - wykonaj FULL backup po zmianie z SIMPLE, aby łańcuch log backupów był poprawny.
