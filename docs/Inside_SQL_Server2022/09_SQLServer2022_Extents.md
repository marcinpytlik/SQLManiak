# 📦 SQL Server 2022 – Extenty (Extent Internals)

---

## 📌 Co to jest extent?

- **Extent** = grupa **8 stron** danych po 8 KB każda.  
- Rozmiar extentu = **64 KB**.  
- Extent to podstawowa jednostka alokacji w SQL Server (dla obiektów > 8 stron).  
- Dzieli się na dwa typy: **uniform** i **mixed**.

---

## 📌 Typy extentów

| Typ       | Opis |
|-----------|------|
| **Uniform extent** | Wszystkie 8 stron należy do **jednego obiektu** (tabela/indeks). |
| **Mixed extent**   | 8 stron może należeć do **różnych obiektów** (do 8). Używane przy małych obiektach, żeby nie marnować miejsca. |

---

## 📌 Jak SQL Server używa extentów?

1. Nowa tabela / indeks:  
   - Najpierw strony z **mixed extentów**.  
   - Po przekroczeniu 8 stron → kolejne alokacje już z **uniform extentów**.

2. Mapowanie extentów kontrolują specjalne strony:  
   - **GAM (Global Allocation Map)** – które extenty są wolne/zajęte.  
   - **SGAM (Shared Global Allocation Map)** – wolne strony w mixed extentach.  
   - **IAM (Index Allocation Map)** – które extenty należą do obiektu.  

---

## 📌 Rozmieszczenie extentów

- Każdy plik bazy danych podzielony na extenty.  
- 1 extent = 64 KB, więc np. plik 1 GB zawiera ~16,384 extentów.  
- Strony kontrolne (PFS, GAM, SGAM, IAM, DCM, BCM) powtarzają się cyklicznie i też zajmują extenty.

---

## 📌 Podgląd extentów w SQL Server

```sql
-- Sprawdź alokację stron/extentów dla tabeli
DBCC IND ('AdventureWorks2022', 'Person.Person', -1);

-- Podejrzyj stronę IAM (mapowanie extentów)
DBCC TRACEON(3604);
DBCC PAGE ('AdventureWorks2022', 1, <IAM_PageID>, 3);
```

---

## 🔎 Podsumowanie

- Extent = 8 stron = 64 KB.  
- **Mixed** – dla małych obiektów (oszczędność miejsca).  
- **Uniform** – dla większych obiektów (wydajność).  
- Zarządzanie extentami → PFS, GAM, SGAM, IAM.  
- DBA patrzy na extenty, gdy analizuje fragmentację, alokacje, albo diagnozuje korupcję.  

---

_ostatnia aktualizacja: 2025-09-16_
