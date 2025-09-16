# 📑 SQL Server 2022 – Typy stron danych (Data Pages)

Każda strona ma **8 KB** (8192 bajty) i nagłówek z metadanymi.  
Typ strony zapisany jest w nagłówku (Page Header, pole `m_type`).  

---

## 🔹 Główne typy stron (najczęściej spotykane)

| Typ | Nazwa                  | Opis |
|-----|-------------------------|------|
| 1   | **Data Page**           | Strony z danymi wierszy tabeli (Heap lub Clustered Index Leaf). |
| 2   | **Index Page**          | Strony wewnętrzne indeksów B-Tree (non-leaf). |
| 3   | **Text/Image Page**     | Dane typu LOB: `text`, `ntext`, `image` (stare typy). |
| 4   | **GAM (Global Allocation Map)** | Rejestruje, które extenty są wolne lub zajęte. |
| 5   | **SGAM (Shared Global Allocation Map)** | Śledzi extenty „mixed”, dostępne dla nowych obiektów. |
| 6   | **IAM (Index Allocation Map)** | Mapowanie obiektu → extenty w różnych plikach/filegroupach. |
| 7   | **PFS (Page Free Space)** | Informacja o wolnym miejscu, statusie strony, ilości slotów. |
| 8   | **Boot Page**           | Metadane bazy: ID, wersja, kompilacja, rozmiar. Zawsze `file_id=1, page_id=9`. |
| 9   | **File Header Page**    | Opis pliku danych: ID, rozmiar, ścieżka. |
| 10  | **Diff Map Page**       | Extenty zmienione od ostatniego FULL backupu. |
| 11  | **ML Map Page** (ML = Min Log) | Extenty zmienione od ostatniego DIFFERENTIAL backupu. |

---

## 🔹 Typy stron dla LOB/row-overflow

| Typ | Nazwa                  | Opis |
|-----|-------------------------|------|
| 13  | **LOB Data Page**       | Dane typu LOB (`varchar(max)`, `nvarchar(max)`, `varbinary(max)`, XML). |
| 14  | **LOB Index Page**      | Struktura indeksowa do zarządzania stronami LOB. |
| 15  | **Row-overflow Page**   | Przechowuje kolumny z wiersza, które nie zmieściły się w 8 KB. |

---

## 🔹 Pozostałe typy specjalne

| Typ | Nazwa                  | Opis |
|-----|-------------------------|------|
| 16  | **IAM Page (Alternate)** | Wewnętrzny wariant IAM, rzadko widoczny w praktyce. |
| 17  | **BCM (Bulk Change Map)** | Śledzi extenty zmienione przez operacje *bulk-logged* (dla backup log). |
| 18  | **DCM (Differential Changed Map)** | Alias dla Diff Map, używany zamiennie. |
| 19+ | **Reserved / Unused**   | Microsoft zarezerwował kody dla przyszłych wersji. |

---

## 🔹 Jak podejrzeć strony w SQL Server

```sql
-- 1. Zlokalizuj strony obiektu
DBCC IND ('AdventureWorks2022', 'Person.Person', -1);

-- 2. Podejrzyj zawartość strony
DBCC TRACEON(3604);
DBCC PAGE ('AdventureWorks2022', 1, <PageID>, 3);
```

---

## 🔎 Podsumowanie
- Strona to **najmniejsza jednostka I/O** w SQL Server (8 KB).  
- Strony grupowane są w **extenty** (8 stron = 64 KB).  
- Metadane i zarządzanie przestrzenią kontrolują specjalne mapy: **PFS, GAM, SGAM, IAM, DCM, BCM**.  
- LOB i row-overflow mają dedykowane typy stron (13–15).  
- Kluczowe dla DBA: znajomość `DBCC IND` i `DBCC PAGE` → troubleshooting korupcji i internals.  

---

_ostatnia aktualizacja: 2025-09-16_
