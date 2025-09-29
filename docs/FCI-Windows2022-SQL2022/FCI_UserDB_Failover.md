# Failover FCI – zachowanie baz użytkownika

## Kluczowa zasada
Baza użytkownika w FCI **nie „migruje”**.  
Podczas przełączenia węzłów robi **crash-recovery** na drugim węźle, korzystając z tych samych plików MDF/NDF/LDF na współdzielonym storage.

---

## Co się dzieje podczas failoveru (Node1 → Node2)

1. **Zerwanie połączeń**  
   - Usługa SQL na Node1 gaśnie.  
   - Wszystkie sesje dostają błąd i znikają.  

2. **Przeniesienie zasobów**  
   - Współdzielone dyski (MDF/NDF/LDF) są „przepięte” do Node2.  
   - To **te same pliki** – nie ma repliki danych.  

3. **Start instancji na Node2 + recovery baz**  
   SQL uruchamia klasyczne etapy:
   - **Analysis** – ustalenie punktu startowego.  
   - **Redo** – odtwarzanie zatwierdzonych transakcji z loga.  
   - **Undo** – wycofywanie transakcji niezatwierdzonych.  

   Dzięki **fast recovery** baza zwykle przechodzi ONLINE po Redo, a Undo działa w tle.  
   (Wydłuży się, jeśli trwały długie transakcje).  

4. **Bufor/BP (Buffer Pool)**  
   - Cały cache z Node1 przepada.  
   - Po failoverze wydajność może być słabsza do czasu ponownego „dogrzania” cache’a.  

5. **Operacje w toku**
   - **Nie-resumowalne** (np. zwykły rebuild indeksu) → przerwane i cofnięte.  
   - **Resumable index rebuild/create** (SQL 2017+) → można wznowić na Node2.  

6. **Agent joby**
   - To ta sama instancja → joby działają na Node2 zgodnie z harmonogramem.  
   - Joby uruchomione w momencie failoveru → zwykle oznaczone jako *failed/aborted*.  
   - Warto mieć retry logic.  

7. **RCSI/SI/Version Store**
   - Wersje były w `tempdb` → znikają.  
   - Zapytania oparte o stare wersje mogą zwrócić błąd i wymagają powtórzenia.  

8. **MSDTC / FILESTREAM / Full-Text**  
   - Muszą być poprawnie sklastrowane.  
   - MSDTC podczas recovery rozwiązuje transakcje *in-doubt*, co może dodać kilka sekund.  

---

## Diagram FCI – failover baz użytkownika

   [Node1 - ACTIVE]                         [Node2 - PASSIVE]
   +-------------------+                    +-------------------+
   | SQL Server        |                    | SQL Server        |
   |                   |                    |                   |
   | Sesje / BufferPool|                    |   (czeka)         |
   | TempDB, Cache     |                    |                   |
   +---------+---------+                    +---------+---------+
             |                                       |
             |     MDF / NDF / LDF (shared disk)     |
             +-------------------+-------------------+
                                 |
                          +------+------+
                          | Shared Disk |
                          +-------------+

Failover →
-----------

1. Node1 gaśnie → wszystkie sesje zerwane, cache utracony.
2. Cluster przepina **Shared Disk** na Node2.
3. Node2 startuje instancję SQL:
     - Analysis
     - Redo (zatwierdzone transakcje)
     - Undo (wycofywanie niezatwierdzonych)
4. Bazy ONLINE po Redo, Undo kończy się w tle (fast recovery).
5. Sesje aplikacyjne łączą się do Node2.

Legenda:
- TempDB zawsze tworzona od nowa (lokalnie lub na współdzielonym storage).
- User DB = te same pliki MDF/NDF/LDF na SAN/CSV.

---

## Jak skrócić czas przełączenia

- **ADR (Accelerated Database Recovery)** → od SQL 2019+, skraca fazę Undo.  
- **Krótki czas trwania transakcji** – unikać 30-minutowych „mega-commitów”.  
- **Autogrow w MB + pre-size plików** – by uniknąć lawiny dogrowów przy starcie.  
- **Log**: nie przesadzać z ogromnym aktywnym ogonem; częste log backupy (model FULL) trzymają recovery pod kontrolą.  
