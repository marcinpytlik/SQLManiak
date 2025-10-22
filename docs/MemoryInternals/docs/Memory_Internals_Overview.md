Za każdą operacją stoi pamięć: **Buffer Pool**, **Memory Clerks**, **Lazy Writer** i **PLE (Page Life Expectancy)**.  
To serce SQL Servera – a każdy spadek PLE to zawał.  
Zrozumienie, jak SQL zarządza stronami danych, to klucz do prawdziwego tuningu.

> „Co nie zmieści się w pamięci, wróci po zemstę z dysku.”

---

## 🧠 Architektura pamięci SQL Server

SQL Server tworzy własny system zarządzania pamięcią i dzieli go na kluczowe obszary:

| Obszar | Opis |
|--------|------|
| **Buffer Pool** | Strony danych (8 KB), cache odczytów/zapisów. |
| **Plan Cache** | Skompilowane plany – zbyt duży ogranicza Buffer Pool. |
| **Memory Clerks** | Menedżerowie pamięci poszczególnych subsystemów. |
| **Workspace Memory** | Pamięć dla sortów, hash joinów, agregacji. |
| **Stolen Memory** | Pamięć „pożyczona” z Buffer Pool na potrzeby wykonania. |
| **Free/Unused** | Rezerwa do rozdysponowania. |

---

## 🔄 Cykl życia strony (Buffer Pool)

1. **Physical Read** → 2. **Use in Query** → 3. **Dirty Page** → 4. **Checkpoint/Lazy Writer** → 5. **Eviction (LRU)**.

---

## 📊 Co i jak monitorować

- **PLE** (Page Life Expectancy) – niskie wartości = presja pamięciowa.  
- **Lazy Writes/sec**, **Checkpoint Pages/sec** – czyszczenie/migotanie bufora.  
- **Memory Grants Pending** – zapytania czekające na przydział pamięci wykonawczej.  
- **Target vs Total Server Memory** – czy SQL osiąga swój limit.  
- **Memory Clerks** – kto faktycznie „zjada” pamięć.

W folderze `scripts/` znajdziesz gotowe zapytania diagnostyczne.

---

## 🧭 Procedura diagnostyczna (skrót)

1. Uruchom `Target_vs_Total_Server_Memory.sql` – sprawdź, czy SQL osiąga target.  
2. `BufferPool_PLE_Counters.sql` – oceń stabilność (trend PLE).  
3. `Memory_Clerks_Overview.sql` – zidentyfikuj największych konsumentów pamięci.  
4. `Memory_Grants_Status.sql` – sprawdź, czy zapytania czekają na granty (i które).  
5. `LazyWriter_Checkpoint_Stats.sql` – zobacz, czy Lazy Writer pracuje ponad normę.  
6. (Opcj.) `BufferPool_ModifiedPages.sql` – ocena „brudnych” stron per baza.  
7. `Waits_Memory_Pressure.sql` – potwierdź presję przez profile waitów.

---

## ✅ Dobre praktyki

- Traktuj **PLE jako trend**, nie jedną liczbę.  
- Zanim dodasz RAM, **zrozum przyczynę** (clerks, duże sorty/hash, złe plany).  
- Ogranicz rozrost **Plan Cache** (parametryzacja, procedury).  
- Pracuj nad **selektywnością zapytań**, aby zmniejszyć I/O i rozmiar grantów.  
- Monitoruj **tempdb** i **spille** (często efekt niedoszacowanych grantów).

📘 Repo zawiera wyłącznie zapytania nieinwazyjne (read-only).
