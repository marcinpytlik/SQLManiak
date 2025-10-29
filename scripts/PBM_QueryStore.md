---
title: "PBM – Weryfikacja włączenia Query Store"
slug: pbm-query-store
tags: [SQLServer, PBM, QueryStore, DBA]
---

## 🎯 Cel
Celem polityki jest **weryfikacja**, czy wszystkie bazy danych użytkownika mają **włączony Query Store** w trybie `READ_WRITE`.  
Dzięki temu administrator może szybko wykryć bazy, w których funkcja QS została wyłączona lub działa tylko w trybie odczytu.

---

## 🧩 Logika działania

Polityka wykorzystuje **funkcję ExecuteSql()** w Policy-Based Management (PBM),  
aby wykonać zapytanie T-SQL w kontekście każdej bazy danych.

Warunek zwraca `1`, jeśli Query Store jest aktywny (`desired_state_desc` lub `actual_state_desc` = `READ_WRITE`),  
lub `0`, jeśli jest wyłączony.

---

## ⚙️ Krok 1 – Utworzenie Condition `QS_ReadWrite_Condition`

**Facet:** `Database`  
**Name:** `QS_ReadWrite_Condition`  
**Expression:**

```sql
ExecuteSql('Numeric', 
N'
SELECT CASE 
  WHEN EXISTS (
    SELECT 1
    FROM sys.database_query_store_options
    WHERE desired_state_desc IN (''READ_WRITE'',''READ_CAPTURE_SECONDARY'')
       OR actual_state_desc  IN (''READ_WRITE'',''READ_CAPTURE_SECONDARY'')
  ) THEN 1 ELSE 0 END;
') = 1
```

---

## ⚙️ Krok 2 – Utworzenie Target Condition `UserDBsOnly`

**Facet:** `Database`  
**Name:** `UserDBsOnly`  
**Expression:**

```sql
@Name NOT IN ('master','model','msdb','tempdb')
```

---

## ⚙️ Krok 3 – Utworzenie Policy `QS_Must_Be_ReadWrite`

**Policy name:** `QS_Must_Be_ReadWrite`  
**Check condition:** `QS_ReadWrite_Condition`  
**Against targets:** `Every Database`  
**Target condition:** `UserDBsOnly`  
**Evaluation mode:**  
- `On Demand` (ręcznie, np. przed aktualizacją środowiska)  
lub  
- `On Schedule` (np. codziennie o 07:00)

---

## 📊 Wynik

Po uruchomieniu **Evaluate** w SSMS:
- ✅ Polityka „Compliant” → baza ma Query Store włączony w trybie READ_WRITE.  
- ❌ Polityka „Not Compliant” → Query Store jest wyłączony lub w trybie READ_ONLY.

---

## 🧪 Szybka weryfikacja T-SQL (poza PBM)

```sql
SELECT 
    d.name AS DatabaseName,
    q.desired_state_desc,
    q.actual_state_desc
FROM sys.databases d
LEFT JOIN sys.database_query_store_options q
    ON d.database_id = q.database_id
WHERE d.database_id > 4;
```

---

## 🧰 Dodatkowe wskazówki

- Możesz ustawić **Evaluation Mode = On Schedule**, by PBM cyklicznie raportował niezgodności.  
- Jeżeli chcesz wymuszać regułę (blokować zmiany), ustaw **On Change: Prevent** – ale tylko po testach.  
- PBM nie zmienia konfiguracji sam – jedynie **monitoruje zgodność**.  
  Jeśli QS ma być włączany automatycznie, użyj dodatkowego joba SQL Agent z:
  ```sql
  ALTER DATABASE [TwojaBaza] SET QUERY_STORE = ON (OPERATION_MODE = READ_WRITE);
  ```

---

## ✅ Podsumowanie

| Element PBM | Nazwa | Typ | Facet | Cel |
|--------------|-------|-----|--------|------|
| Condition | QS_ReadWrite_Condition | ExecuteSql | Database | Sprawdza stan Query Store |
| Target Condition | UserDBsOnly | Expression | Database | Wyklucza systemowe bazy |
| Policy | QS_Must_Be_ReadWrite | Policy | Database | Weryfikuje Query Store w user DB |

---

📘 *Ta polityka pozwala w prosty sposób monitorować, czy wszystkie bazy danych mają włączony Query Store – kluczowe narzędzie diagnostyczne i optymalizacyjne w SQL Server 2016–2022.*
