# 🎯 Strategia backupów w SQL Server 2022

## 1️⃣ Bazy systemowe

### 📚 msdb
- Zawiera: joby SQL Agent, historię backupów, operatorów, alerty.
- **Backup**:
  - FULL raz dziennie.
  - Dodatkowo przed każdą większą zmianą (np. import jobów, nowe harmonogramy).
- **Recovery model**: SIMPLE (wystarczający).
- **Uwagi**: odtwarzanie msdb jest krytyczne do przywrócenia całej automatyki jobów.

### 📚 master
- Zawiera: loginy, konfigurację serwera, informacje o bazach.
- **Backup**:
  - FULL po każdej zmianie konfiguracji (np. nowy login, linked server, zmiana collation).
  - Minimum raz w tygodniu.
- **Recovery model**: SIMPLE.
- **Uwagi**: przywrócenie master może być trudniejsze, bo trzeba startować w `-m` (single user).

### 📚 model
- Szablon dla nowych baz.
- **Backup**:
  - FULL po każdej zmianie w ustawieniach model (np. default collation, recovery model).
- **Recovery model**: FULL (ale praktycznie nie ma log backupów).
- **Uwagi**: rzadko się zmienia, ale kopia obowiązkowa w DR.

### 📚 tempdb
- **Backup**: ❌ brak — tempdb odtwarza się pusty przy każdym restarcie.
- **Uwagi**: monitoruj parametry (rozmiar, autogrowth), ale nie backupuj.

---

## 2️⃣ Bazy użytkownika

### 🔹 Recovery Model: FULL
- **Scenariusz OLTP (np. systemy transakcyjne)**  
  - FULL backup – raz dziennie (np. noc).  
  - DIFF backup – co 6h (opcjonalnie, by skrócić czas restore).  
  - LOG backup – co 15 minut.  
- **Cel**: RPO ≤ 15 min, RTO – zależnie od wielkości bazy.  
- **Uwagi**: bez regularnych log backupów plik `.ldf` urośnie bez końca.

### 🔹 Recovery Model: SIMPLE
- **Scenariusz: systemy testowe / raportowe / staging**  
  - FULL backup – raz dziennie (noc).  
  - DIFF backup – co kilka godzin (opcjonalnie).  
  - Brak log backupów (log sam się skraca po checkpoint).  
- **Cel**: wystarczy odtworzenie do ostatniego backupu, punkt-in-time niepotrzebny.

### 🔹 Recovery Model: BULK_LOGGED
- **Scenariusz: systemy z dużymi operacjami BULK (importy, ETL)**  
  - FULL backup – raz dziennie.  
  - DIFF backup – co kilka godzin.  
  - LOG backup – co 30 minut (uwaga: przy bulk-logged log backup może być duży).  
- **Cel**: kompromis między wydajnością a możliwością odtwarzania do punktu w czasie.  

---

## 3️⃣ Zasady ogólne

- **Backup lokalny + zewnętrzny**: zawsze trzymaj kopię poza serwerem (inne storage, Azure Blob, S3).
- **Test restore**: raz w tygodniu test odtwarzania (RPO/RTO to nie teoria, tylko praktyka).
- **Kompresja**: włączona domyślnie (`sp_configure 'backup compression default', 1`).
- **Szyfrowanie**: zawsze dla środowisk produkcyjnych.
- **Retention**: polityka zgodna z RPO/RTO i compliance (np. trzymanie 14–30 dni backupów online).
- **Backup system databases + user databases**: traktować jako jedną całość — backup samych baz użytkownika bez msdb/master utrudnia recovery serwera.

---

## ✅ Checklist DBA

- [ ] Full backup **msdb/master/model** zgodnie z harmonogramem.
- [ ] Tempdb – monitorowanie, bez backupu.
- [ ] Każda baza użytkownika ma zdefiniowany recovery model → czy odpowiada RPO/RTO?
- [ ] Harmonogram: FULL (noc), DIFF (co 6h), LOG (co 15 min) — OLTP.
- [ ] Automatyczna weryfikacja backupów (`RESTORE VERIFYONLY`).
- [ ] Regularny **test restore** w środowisku DR.
