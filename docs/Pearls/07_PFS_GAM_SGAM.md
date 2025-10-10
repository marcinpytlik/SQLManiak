
# 07 – PFS / GAM / SGAM

**Idea:** Strony kontrolne śledzą zajętość i wolne extenty. Zrozum je, a zrozumiesz „skąd ten wait”.

- **PFS (Page Free Space)**: ile wolnego miejsca na stronie (alokacje wierszy).
- **GAM (Global Allocation Map)**: które extenty są wolne.
- **SGAM (Shared GAM)**: które extenty mają wolne strony (mixed).

## Ścieżka do diagnostyki
```sql
DBCC TRACEON(3604);
DBCC PAGE (DB_ID(), 1, 1, 3);   -- PFS strona (przykład; adres zależy od DB)
DBCC PAGE (DB_ID(), 2, 1, 3);   -- GAM
DBCC PAGE (DB_ID(), 3, 1, 3);   -- SGAM
```

**Uwaga:** DBCC PAGE jest nieudokumentowane; używaj w labie/testach.
