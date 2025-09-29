# 🗄️ Backup w SQL Server – mechanizmy wewnętrzne

## 🔹 Full Backup – kroki wewnętrzne
1. SQL Server zapisuje **checkpoint** → wszystkie zmiany z buffer pool do pliku danych.  
2. Tworzony jest **snapshot logu** (punkt LSN początkowy backupu).  
3. Backup engine czyta **strony danych (8 KB)**:
   - ze wszystkich plików `.mdf` / `.ndf`,
   - w kolejności extentów.  
4. Każda strona dostaje nagłówek + checksum.  
5. Strumień stron zapisywany jest do pliku `.bak`.  
6. Na końcu zapisywany jest **TOC** (table of contents) z listą plików/filegroupów.  

---

## 🔹 Differential Backup – kroki
1. Odczytaj z DCM (Differential Change Map), które extenty zmieniły się od ostatniego FULL.  
2. Dla extentów oznaczonych jako `1` → czytaj wszystkie 8 stron.  
3. Zapisz do pliku `.bak` tylko te extenty.  
4. Dodaj metadane z LSN (z którego FULL i jakie zmiany obejmuje).  

---

## 🔹 Log Backup – kroki
1. Sprawdź LSN końcowy poprzedniego log backupu.  
2. Zidentyfikuj, które **VLF-y** zawierają nowe transakcje.  
3. Odczytaj sekwencyjnie wpisy logu od `last LSN` do `current LSN`.  
4. Zapisz transakcje do pliku `.trn` w kolejności.  
5. Zaktualizuj `last LSN` w metadanych (dla następnego log backupu).  

---

## 🔹 ASCII – Backup chain (LSN)

```
     [FULL BACKUP]
        LSN: 100
           |
           v
     [DIFF BACKUP]
        LSN: 140 (zmiany od FULL)
           |
           v
   +----------------+
   |                |
   v                v
[LOG BACKUP]    [LOG BACKUP]
 LSN:140-160     LSN:160-180
   |                |
   +-------►--------+
           v
     [RESTORE POINT]
```

---

## 🔹 ASCII – Differential z DCM

```
DCM Page (1 bit = 1 extent)
+--------+--------+--------+--------+
| Extent | Status | Extent | Status |
+--------+--------+--------+--------+
|   1    |   0    |   2    |   1*   |
|   3    |   0    |   4    |   1*   |
+--------+--------+--------+--------+
 * = zmienione od FULL -> trafi do DIFF
```

---

## 🔹 ASCII – Log backup z VLF

```
Log file (.ldf)
+--------+--------+--------+
|  VLF1  |  VLF2  |  VLF3  |
| [x][x] | [x][x] | [ ]    |
+--------+--------+--------+
      |        |
      v        v
   Backup log (LSN 140-160)
```

---

## ✅ Checklist – co sprawdzić
- [ ] Czy backup chain jest pełny i spójny (FULL → DIFF → LOG)?  
- [ ] Czy LSN backupu pokrywa wymagane RPO/RTO?  
- [ ] Czy testowałeś restore (`RESTORE VERIFYONLY` + test odtwarzania)?  
- [ ] Czy log backupy są wykonywane wystarczająco często?  
- [ ] Czy nie masz uszkodzonych stron w DCM/BCM?  
