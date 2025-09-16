# 📑 SQL Server 2022 — Rodzaje indeksów

---

## 🔹 1. Clustered Index
- **Opis**: fizycznie sortuje dane w tabeli wg klucza klastra. Każda tabela może mieć max 1 clustered index.  
- **Zastosowanie**: kolumny unikalne, często filtrowane w zapytaniach zakresowych.  
- **Wady**: zmiana wartości klucza = przeniesienie wiersza.  
- **Uwagi**: domyślnie tworzony przy `PRIMARY KEY`, chyba że jawnie zadeklarowano jako nonclustered.

---

## 🔹 2. Nonclustered Index
- **Opis**: osobna struktura B-Tree, zawiera klucz + wskaźnik do danych (RID lub klucz klastra).  
- **Zastosowanie**: kolumny często w WHERE, JOIN, ORDER BY.  
- **Uwagi**: może być wiele na tabeli. Można dodać **INCLUDE** dla kolumn niekluczowych.

---

## 🔹 3. Unique Index
- **Opis**: wymusza unikalność wartości w kolumnie/kolumnach.  
- **Uwagi**: każdy `PRIMARY KEY` = unique clustered (domyślnie), `UNIQUE` constraint = unique nonclustered (chyba że zmienisz).

---

## 🔹 4. Columnstore Index
- **Opis**: dane przechowywane kolumnowo, segmenty + dictionary encoding + batch mode.  
- **Rodzaje**:
  - **Clustered Columnstore (CCI)** – cała tabela kolumnowo (typowe w DW).  
  - **Nonclustered Columnstore (NCCI)** – obok tabeli rowstore, np. hybryda OLTP + analityka.  
- **Zastosowanie**: hurtownie danych, analizy, agregacje dużych wolumenów.  
- **Uwagi**: od SQL 2016 możliwe update’y, od SQL 2019 indeksy kolumnowe na tabelach z LOB.

---

## 🔹 5. Filtered Index
- **Opis**: indeks częściowy, tylko dla podzbioru danych (`WHERE`).  
- **Zastosowanie**: kolumny o dużej liczbie wartości NULL / rzadko używane subsety.  
- **Uwagi**: oszczędność miejsca i IO.

---

## 🔹 6. Indexed View
- **Opis**: materializowany widok z clustered index.  
- **Zastosowanie**: akceleracja agregacji, denormalizacja.  
- **Wymagania**: SET-y (`ANSI_NULLS`, `QUOTED_IDENTIFIER`, deterministyczne funkcje).  
- **Uwagi**: pierwszy indeks zawsze **clustered unique**.

---

## 🔹 7. Full-Text Index
- **Opis**: osobny mechanizm (Full-Text Catalog), przeszukiwanie tekstów z tokenizacją i językami.  
- **Zastosowanie**: wyszukiwanie słów, prefiksów, stemming, ranking FREETEXT/CONTAINS.  
- **Uwagi**: wymaga serwisu Full-Text Search.

---

## 🔹 8. XML Index
- **Rodzaje**:
  - **Primary XML Index** – shredding XML do wewn. tabeli.  
  - **Secondary XML Indexes** – PATH, VALUE, PROPERTY.  
- **Zastosowanie**: zapytania XQuery w kolumnach XML.  
- **Uwagi**: zajmują dużo miejsca.

---

## 🔹 9. Spatial Index
- **Opis**: indeks na kolumnach typu `geometry` i `geography`.  
- **Zastosowanie**: zapytania STIntersects, STWithin, STDistance.  
- **Uwagi**: używa gridów lub filtrów dla optymalizacji.

---

## 🔹 10. Memory-Optimized Indexes (dla Hekaton)
- **Rodzaje**:
  - **Nonclustered Hash Index** – super szybki dostęp przy równomiernym rozkładzie hash.  
  - **Nonclustered Range Index (B-Tree)** – dla zakresów i sortowań.  
- **Uwagi**: istnieją tylko w tabelach memory-optimized.

---

## 🔹 11. Partitioned Index
- **Opis**: indeks oparty o partition function/scheme.  
- **Zastosowanie**: duże tabele z podziałem na zakresy (np. dane historyczne).  
- **Uwagi**: zarządzanie partycjami bez konieczności reindeksowania całości.

---

## 🔹 12. Clustered vs Heap
- **Heap** = tabela bez clustered index (tylko strona danych).  
- Zwykle zaleca się **zawsze mieć clustered index**, chyba że tabela typowo staging/ETL.

---

## 🔎 Podsumowanie

- **Rowstore**: clustered, nonclustered, unique, filtered, indexed views.  
- **Columnstore**: clustered, nonclustered.  
- **Specjalne**: full-text, XML, spatial, memory-optimized.  
- **Architektura**: heap vs clustered.  
- **Zaawansowane**: partitioned indexes, indexed views.

---

_ostatnia aktualizacja: 2025-09-16_
