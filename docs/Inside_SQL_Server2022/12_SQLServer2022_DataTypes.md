# 🔢 SQL Server 2022 – Typy danych

Każda kolumna/zmienna musi mieć określony typ danych.  
Typy dzielą się na **wbudowane (native)** oraz **CLR/rozszerzone**.

---

## 📌 1. Typy liczbowe

| Typ         | Zakres / precyzja | Rozmiar | Native/CLR | Uwagi |
|-------------|-------------------|---------|------------|-------|
| **bit**     | 0 / 1 / NULL      | 1 bajt (współdzielony) | Native | Do wartości logicznych. |
| **tinyint** | 0 – 255           | 1 bajt  | Native | Tylko dodatnie. |
| **smallint**| -32,768 – 32,767  | 2 bajty | Native | Liczby całkowite. |
| **int**     | -2,147,483,648 – 2,147,483,647 | 4 bajty | Native | Najczęściej używany. |
| **bigint**  | ±9.22e18          | 8 bajtów| Native | Duże zakresy. |
| **decimal(p,s)** | 1–38 cyfr, skala 0–38 | 5–17 bajtów | Native | Precyzyjny typ finansowy. |
| **numeric(p,s)** | = decimal     | = decimal | Native | Synonim decimal. |
| **smallmoney** | -214,748.3648 – 214,748.3647 | 4 bajty | Native | Starszy, ma ograniczenia. |
| **money**   | ±922,337,203,685,477.5807 | 8 bajtów | Native | Duży zakres, ale 4 miejsca po przecinku. |
| **float(n)**| IEEE 754, ~1.7e-308 – 1.7e308 | 4 (24-bit) / 8 bajtów (53-bit) | Native | Zmiennoprzecinkowy. |
| **real**    | ~3.4e-38 – 3.4e38 | 4 bajty | Native | Float(24). |

---

## 📌 2. Typy znakowe

| Typ         | Rozmiar           | Native/CLR | Uwagi |
|-------------|-------------------|------------|-------|
| **char(n)** | Stała długość, 1–8000 znaków | Native | ASCII, fixed. |
| **varchar(n)** | Zmienna długość, 1–8000 | Native | ASCII, variable. |
| **varchar(max)** | Do 2^31-1 znaków | Native (LOB) | Przechowywane jako LOB. |
| **nchar(n)** | Stała długość, 1–4000 | Native | Unicode (2 bajty/znak). |
| **nvarchar(n)** | Zmienna długość, 1–4000 | Native | Unicode. |
| **nvarchar(max)** | Do 2^31-1 znaków | Native (LOB) | Unicode LOB. |
| **text**    | Do 2^31-1 znaków | Native (deprecated) | Nie używać – zastąpić varchar(max). |
| **ntext**   | Do 2^30-1 znaków | Native (deprecated) | Zastąpić nvarchar(max). |

### ℹ️ Uwaga dotycząca rozmiaru znaków

- Dla typów **char/varchar** – rozmiar `n` oznacza **n bajtów**, a nie zawsze n znaków.  
- Jeśli używasz kolacji **jednobajtowej** (np. `SQL_Latin1_General_CP1_CI_AS`), to `varchar(50)` = 50 znaków i 50 bajtów.  
- Jeśli używasz kolacji **wielobajtowej** (np. UTF-8), to `varchar(50)` = 50 bajtów, co może oznaczać np. tylko 25 znaków (gdy każdy zajmuje 2 bajty).  
- Dla **nchar/nvarchar** zawsze rezerwowane są **2 bajty na znak**, więc `nvarchar(50)` = zawsze 50 znaków = 100 bajtów.  

---

## 📌 3. Typy binarne

| Typ         | Rozmiar           | Native/CLR | Uwagi |
|-------------|-------------------|------------|-------|
| **binary(n)** | Stała długość, 1–8000 bajtów | Native | Fixed-length binary. |
| **varbinary(n)** | Zmienna długość, 1–8000 | Native | Variable binary. |
| **varbinary(max)** | Do 2^31-1 bajtów | Native (LOB) | Duże dane binarne. |
| **image**   | Do 2^31-1 bajtów | Native (deprecated) | Zastąpić varbinary(max). |
| **rowversion / timestamp** | 8 bajtów | Native | Unikalna wartość binarna (auto). |

---

## 📌 4. Typy daty i czasu

| Typ         | Zakres / dokładność | Rozmiar | Native/CLR | Uwagi |
|-------------|---------------------|---------|------------|-------|
| **date**    | 0001-01-01 – 9999-12-31 | 3 bajty | Native | Bez czasu. |
| **datetime**| 1753-01-01 – 9999-12-31, dokładność 3.33 ms | 8 bajtów | Native | Starszy, gorsza precyzja. |
| **datetime2** | 0001-01-01 – 9999-12-31, precyzja do 100 ns | 6–8 bajtów | Native | Nowszy, lepsza precyzja. |
| **smalldatetime** | 1900-01-01 – 2079-06-06, dokładność 1 minuta | 4 bajty | Native | Mniejszy zakres. |
| **time(p)** | 00:00:00.0000000 – 23:59:59.9999999, precyzja 0–7 | 3–5 bajtów | Native | Tylko czas. |
| **datetimeoffset(p)** | Jak datetime2 + offset strefy czasowej | 8–10 bajtów | Native | Dla danych z TZ. |

---

## 📌 5. Typy specjalne

| Typ         | Rozmiar           | Native/CLR | Uwagi |
|-------------|-------------------|------------|-------|
| **uniqueidentifier** | 16 bajtów | Native | GUID (UUID v4). |
| **sql_variant** | Zmienny | Native | Może przechowywać różne typy (int, varchar, itd.). |
| **xml**     | Do 2^31-1 znaków | Native (LOB) | XML + opcjonalne schematy XSD. |
| **hierarchyid** | ~40 bajtów/poziom | CLR | Przechowywanie hierarchii w drzewach. |
| **geometry** | Do 2 GB | CLR (SQL Server Spatial) | Typ przestrzenny 2D. |
| **geography** | Do 2 GB | CLR (SQL Server Spatial) | Typ przestrzenny geograficzny (GPS). |
| **json**    | Brak osobnego typu | – | Reprezentowany jako `nvarchar(max)`, ale z funkcjami JSON. |

---

## 📌 6. Typy CLR i UDT (User-Defined Types)

- **hierarchyid**, **geometry**, **geography** → dostarczone w CLR.  
- Możesz też tworzyć własne typy CLR w .NET (`CREATE TYPE ... EXTERNAL NAME`).  

---

## 📌 7. Typy tabelaryczne i struktury

| Typ         | Native/CLR | Uwagi |
|-------------|------------|-------|
| **table**   | Native | Typ zmiennej tabelarycznej (`DECLARE @t TABLE`). |
| **user-defined table type (UDTT)** | Native | Tworzone przez `CREATE TYPE ... AS TABLE`, do TVP (Table-Valued Parameters). |

---

## 📌 8. Synonimy / przestarzałe

- `timestamp` → alias `rowversion`.  
- `ntext`, `text`, `image` → **deprecated** od SQL 2005+.  
- `money`, `smallmoney` → dostępne, ale w wielu projektach zastępowane `decimal`.  

---

## 🔎 Podsumowanie

- **Native** (rdzenne): int, bigint, decimal, float, char, varchar, nvarchar, varbinary, date, datetime2, time, uniqueidentifier, xml, sql_variant, table.  
- **CLR**: hierarchyid, geometry, geography, custom CLR UDT.  
- **Deprecated**: text, ntext, image, timestamp (rowversion alias), money/smallmoney (zalecane decimal).  
- JSON → nie jako typ, tylko nvarchar(max) + funkcje JSON.  

---

_ostatnia aktualizacja: 2025-09-16_
