# Compatibility Level – Przykłady wpływu na zapytania

## 1. Parameter Sensitive Plan Optimization (PSP)

### CL 130 (SQL Server 2016)
Jeden plan dla wszystkich wartości parametru → może być nieoptymalny przy skośnych danych.

```sql
DECLARE @Category CHAR(1) = 'A'; -- bardzo częsta wartość
SELECT COUNT(*) FROM dbo.SkewedData WHERE Category = @Category;

SET @Category = 'B'; -- rzadka wartość
SELECT COUNT(*) FROM dbo.SkewedData WHERE Category = @Category;
```

- Przy `A` → Index Scan.
- Przy `B` → nadal Index Scan, choć Seek byłby lepszy.

### CL 160 (SQL Server 2022)
Dzięki **PSP Optimization** SQL Server tworzy kilka wariantów planu i wybiera najlepszy.
- Dla `A` → Scan.
- Dla `B` → Seek.

---

## 2. Scalar UDF Inlining

### CL 130
Funkcje skalarne są wołane interpretacyjnie, co generuje narzut dla każdego wiersza.

### CL 160
SQL Server inline’uje treść funkcji w plan → brak dodatkowego narzutu.

```sql
CREATE FUNCTION dbo.fn_AddVAT(@price DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN @price * 1.23;
END;
GO

SELECT TOP(1000) dbo.fn_AddVAT(ListPrice)
FROM Production.Product;
```

- CL 130 → funkcja wywoływana 1000 razy.
- CL 160 → inline → dużo szybciej.

---

## 3. Batch Mode on Rowstore

### CL 130
Batch Mode tylko dla Columnstore.

### CL 160
Batch Mode dostępny również dla rowstore (B-Tree).

```sql
SELECT Color, AVG(ListPrice), COUNT(*)
FROM Production.Product
GROUP BY Color;
```

- CL 130 → Row Mode.
- CL 160 → Batch Mode on Rowstore → wielokrotnie szybsze.

---

## 4. Adaptive Joins i Memory Grant Feedback

### CL 130
Plan na sztywno – Nested Loop albo Hash Join.

### CL 160
- Adaptive Join – plan z gałęziami, które wybierane są podczas wykonania.
- Memory Grant Feedback – korekta przydziału pamięci dla kolejnych wykonań.

```sql
SELECT p.ProductID, s.SalesOrderID
FROM Production.Product p
JOIN Sales.SalesOrderDetail s
    ON p.ProductID = s.ProductID
WHERE p.Color = 'Black';
```

- CL 130 → zawsze ten sam join.
- CL 160 → Adaptive Join + lepsze zarządzanie pamięcią.

---

## Podsumowanie
- **CL 130** → statyczne plany, brak adaptacji, wolniejsze funkcje UDF.
- **CL 160** → PSP, UDF Inlining, Batch Mode on Rowstore, Adaptive Joins, Memory Grant Feedback → szybsze i inteligentniejsze wykonywanie zapytań.
