# ⚡ Accelerated Database Recovery (ADR) a backupy

## 🔹 Co to jest ADR?
- Mechanizm wprowadzony w SQL Server 2019, domyślnie **włączony w 2022**.
- Zmienia sposób, w jaki SQL Server obsługuje **recovery** (odtwarzanie po restarcie, rollback, restore).
- Oparty o:
  - **Persisted Version Store (PVS)** – wersje stron zapisywane w pliku danych, zamiast w tempdb.
  - **Logical Revert** – szybki rollback transakcji przez oznaczanie ich jako nieaktualne, zamiast fizycznego cofania każdej zmiany.

---

## 🔹 Jak włączyć ADR?
- W SQL Server 2019: domyślnie OFF → trzeba włączyć ręcznie:
```sql
ALTER DATABASE AdventureWorks2019
SET ACCELERATED_DATABASE_RECOVERY = ON;
```
- W SQL Server 2022: nowe bazy mają ADR **ON** domyślnie.
- Jeśli przenosisz bazę ze starszej wersji (2016/2017/2019), po restore ADR może być OFF → włącz ręcznie.

Sprawdzenie statusu:
```sql
SELECT name, is_accelerated_database_recovery_on
FROM sys.databases;
```

Wyłączenie ADR (np. w razie problemów):
```sql
ALTER DATABASE AdventureWorks2022
SET ACCELERATED_DATABASE_RECOVERY = OFF;
```

---

## 🔹 Wpływ ADR na BACKUP
- **Backup Full / Diff**:
  - Kopiuje również struktury **Persisted Version Store**.
  - Dzięki temu restore może wykorzystać ADR do szybszego recovery.
- **Backup Log**:
  - Log jest „odchudzony” – nie trzeba w nim trzymać wersji stron dla rollbacków, bo są w PVS.
  - Log backupy mogą być mniejsze i bardziej przewidywalne.
- **Recovery po restore**:
  - Dzięki ADR **czas odtwarzania** (np. po dużej transakcji) jest dramatycznie krótszy.
  - SQL Server nie musi cofać transakcji fizycznie strona po stronie — używa Logical Revert.

---

## 🔹 Konsekwencje dla DBA
- Backup **zawiera dodatkowe struktury** (PVS), więc nieco rośnie jego rozmiar względem starego modelu.
- Restore jest **zdecydowanie szybszy** i stabilniejszy, zwłaszcza w dużych bazach z długimi transakcjami.
- Niektóre scenariusze bulk-logged i operacje minimalnie logowane wyglądają inaczej, bo ADR trzyma dodatkowe metadane.
- W plikach danych (`.mdf/.ndf`) pojawia się dodatkowa przestrzeń na **Persisted Version Store** – monitoruj rozmiar.

---

## 🔹 Podsumowanie
- **Przed ADR**: rollback i recovery zależały od logu — im dłuższa transakcja, tym dłużej trwało odtwarzanie.  
- **Z ADR**: log odchudzony, backup zawiera wersje w PVS, recovery i rollback są niemal natychmiastowe.  
- **Dla backupów**: rozmiar ↑ minimalnie, czas restore ↓ znacząco.  

👉 To jest powód, dla którego w SQL Server 2022 **backup + restore** są dużo bardziej przewidywalne w czasie niż w 2016/2017.
