# 📋 Szablon Checklisty

**Cel checklisty:** [tu wpisz, np. "Weryfikacja po aktualizacji SQL Server"]  
**Autor:** [imię/nazwisko]  
**Data utworzenia:** [rrrr-mm-dd]  
**Odbiorca:** [np. administrator, junior DBA, użytkownik końcowy]  

---

## ✅ Kroki

1. [ ] Uruchom usługę [nazwa_usługi].  
2. [ ] Sprawdź log w katalogu [ścieżka].  
3. [ ] Zweryfikuj status bazy danych `DB_NAME()` w SSMS/VS Code.  
4. [ ] Wykonaj polecenie T-SQL:  
   ```sql
   SELECT name, state_desc FROM sys.databases;
   ```
5. [ ] Porównaj wynik z oczekiwanym stanem (np. wszystkie ONLINE).  
6. [ ] Sprawdź alerty w systemie monitoringu (Grafana/InfluxDB).  
7. [ ] Potwierdź wykonanie backupu FULL w ciągu ostatnich 24h.  
8. [ ] Odhacz wszystkie punkty powyżej.  

---

## 📝 Notatki po wykonaniu

- [miejsce na uwagi, poprawki, komentarze]  
- [np. "Punkt 3 wymaga doprecyzowania – dodać ścieżkę"]  

---

## 🔄 Iteracja

- Data aktualizacji: [rrrr-mm-dd]  
- Zmiany: [opis zmian]  
