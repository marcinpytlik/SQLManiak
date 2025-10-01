# Checklist — Backup/Restore (VLDB)
- [ ] **FULL** wykonywany filegroupowo (`FG_HOT`,`FG_WARM`; `FG_COLD`/`ARCHIVE` rzadziej).
- [ ] **DIFF** w cyklu godzinowym/dziennym dla `FG_HOT`.
- [ ] **LOG** co 5–15 min (zależnie od RPO).
- [ ] Striping do ≥ 4 urządzeń + kompresja.
- [ ] Szyfrowanie backupów (certyfikat/asym. klucz) + rotacja kluczy.
- [ ] Test **restore verifyonly** + okresowe testy odtworzeniowe (w tym **piecemeal restore**).
- [ ] Monitorowanie rozmiaru loga i redo queue na replikach.
