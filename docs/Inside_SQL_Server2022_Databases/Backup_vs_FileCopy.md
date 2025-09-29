# 📂 Backup vs Kopiowanie plików MDF/LDF

## 🔹 Backup DATABASE / LOG (prawidłowo)
- SQL Server wykonuje **fuzzy checkpoint**,  
- Kopiuje strony danych (MDF/NDF),  
- Dogrywa log transakcyjny,  
- Tworzy **spójną kopię**, którą można przywrócić,  
- W recovery model FULL/BULK_LOGGED → następuje **truncation logu** (po backupie logu).  

👉 Efekt: **kopia spójna, bezpieczna do restore**.

---

## 🔸 Ręczne kopiowanie plików MDF/LDF (nieprawidłowo)
- System operacyjny kopiuje pliki,  
- W tym czasie SQL Server nadal zapisuje dane do logu i buforów,  
- Kopia jest **niespójna** – części danych może brakować,  
- Brak truncation logu,  
- Przy próbie attach/restore ryzyko `SUSPECT`.  

👉 Efekt: **kopii nie można traktować jako backupu**.

---

## 🔧 Diagram
![SQL Server Backup vs File Copy](SQLServer_Backup_vs_FileCopy.png)

---

## 🧩 Wnioski
- Do zabezpieczenia danych używamy tylko `BACKUP DATABASE` / `BACKUP LOG` albo narzędzi VSS (snapshot).  
- Ręczne kopiowanie plików bazy nigdy nie zastąpi backupu.  
- Prawidłowy backup = możliwość odtworzenia + kontrola nad logiem.  
