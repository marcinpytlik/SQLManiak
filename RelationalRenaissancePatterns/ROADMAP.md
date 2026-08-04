# Roadmapa 52 odcinków

01. **Expand–Migrate–Contract** — `01-Schema-Evolution/01-Expand-Migrate-Contract`  
    Bezpieczna zmiana schematu przez dodanie nowej struktury, migrację danych i dopiero późniejsze usunięcie starej.

02. **Shadow Column** — `01-Schema-Evolution/03-Shadow-Column`  
    Dodanie nowej kolumny obok starej i stopniowe przełączenie aplikacji.

03. **Backfill in Batches** — `01-Schema-Evolution/04-Backfill-in-Batches`  
    Uzupełnianie danych małymi partiami zamiast jednej dużej transakcji.

04. **Dual Write** — `01-Schema-Evolution/02-Dual-Write`  
    Równoległy zapis do starego i nowego modelu w okresie przejściowym.

05. **Compatibility View** — `01-Schema-Evolution/05-Compatibility-View`  
    Widok udostępniający stary kontrakt po zmianie fizycznego modelu.

06. **Optimistic Concurrency** — `05-Concurrency-Integrity/01-Optimistic-Concurrency`  
    Wykrywanie konfliktu podczas zapisu, np. za pomocą rowversion.

07. **Idempotency Key** — `05-Concurrency-Integrity/05-Idempotency-Key`  
    Klucz żądania chroniący przed podwójnym wykonaniem.

08. **Transactional Outbox** — `06-Integration/01-Transactional-Outbox`  
    Zapis danych biznesowych i komunikatu w jednej transakcji.

09. **Soft Delete** — `04-Deletion-Retention/02-Soft-Delete`  
    Logiczne oznaczenie rekordu jako usuniętego.

10. **Soft Delete with Filtered Unique Index** — `04-Deletion-Retention/03-Soft-Delete-Filtered-Unique`  
    Unikalność tylko dla aktywnych rekordów.

11. **Temporal Tables** — `03-History-Audit/02-Temporal-Tables`  
    Historia danych obsługiwana przez system-versioned temporal tables SQL Server.

12. **Audit Trail** — `03-History-Audit/01-Audit-Trail`  
    Osobna tabela zmian z informacją kto, kiedy i co zmienił.

13. **Effective Dating** — `03-History-Audit/03-Effective-Dating`  
    Rekord obowiązuje w określonym przedziale czasu.

14. **Association Table** — `02-Data-Modeling/08-Association-Table`  
    Jawna encja realizująca relację wiele-do-wielu.

15. **Adjacency List** — `02-Data-Modeling/04-Adjacency-List`  
    Hierarchia oparta na kluczu ParentId.

16. **Closure Table** — `02-Data-Modeling/05-Closure-Table`  
    Tabela przechowująca wszystkie relacje przodek–potomek.

17. **Materialized Path** — `02-Data-Modeling/06-Materialized-Path`  
    Hierarchia przechowywana jako ścieżka.

18. **Table per Hierarchy** — `02-Data-Modeling/01-TPH`  
    Jedna tabela dla całej hierarchii typów z kolumną dyskryminatora.

19. **Table per Type** — `02-Data-Modeling/02-TPT`  
    Osobna tabela dla typu bazowego i każdego podtypu.

20. **Table per Concrete Type** — `02-Data-Modeling/03-TPC`  
    Osobna kompletna tabela dla każdego konkretnego typu.

21. **Filtered Index** — `07-Performance/02-Filtered-Index`  
    Indeks obejmuje tylko wybrany podzbiór danych.

22. **Covering Index** — `07-Performance/01-Covering-Index`  
    Indeks zawiera wszystkie kolumny potrzebne zapytaniu.

23. **Keyset Pagination** — `07-Performance/11-Keyset-Pagination`  
    Stronicowanie przez ostatni klucz zamiast OFFSET.

24. **Materialized Aggregate** — `07-Performance/07-Materialized-Aggregate`  
    Przechowywanie wcześniej obliczonych agregatów.

25. **Read Model** — `07-Performance/10-Read-Model`  
    Osobny model zoptymalizowany pod zapytania.

26. **Application Lock** — `05-Concurrency-Integrity/08-Application-Lock`  
    Synchronizacja procesów za pomocą sp_getapplock.

27. **Unique Constraint as Guard** — `05-Concurrency-Integrity/06-Unique-Constraint-Guard`  
    Baza wymusza unikalność i chroni przed wyścigiem.

28. **Check Constraint as Domain Rule** — `05-Concurrency-Integrity/07-Check-Constraint-Domain`  
    Reguła domenowa wymuszona ograniczeniem CHECK.

29. **Inbox Pattern** — `06-Integration/02-Inbox`  
    Ochrona konsumenta przed ponownym przetworzeniem wiadomości.

30. **Change Data Capture** — `06-Integration/03-Change-Data-Capture`  
    Odczytywanie zmian danych z mechanizmu CDC.

31. **Change Tracking** — `06-Integration/04-Change-Tracking`  
    Lekki mechanizm wykrywania, które wiersze się zmieniły.

32. **Polling Publisher** — `06-Integration/05-Polling-Publisher`  
    Proces okresowo pobiera nieopublikowane komunikaty.

33. **Archive then Delete** — `04-Deletion-Retention/04-Archive-Then-Delete`  
    Przeniesienie danych do archiwum przed usunięciem.

34. **Retention Policy** — `04-Deletion-Retention/06-Retention-Policy`  
    Automatyczne usuwanie danych starszych niż określony okres.

35. **Partition Switching for Purge** — `04-Deletion-Retention/07-Partition-Switching-Purge`  
    Szybkie usuwanie dużych zakresów danych przez przełączenie partycji.

36. **Partitioning** — `07-Performance/03-Partitioning`  
    Podział dużej tabeli na partycje.

37. **Hot and Cold Data Separation** — `07-Performance/04-Hot-Cold-Separation`  
    Oddzielenie często używanych danych od archiwalnych.

38. **Row-Level Security** — `08-Security/04-Row-Level-Security`  
    Filtrowanie wierszy zależnie od kontekstu użytkownika.

39. **Module Signing** — `08-Security/01-Module-Signing`  
    Nadawanie procedurze dodatkowych uprawnień przez podpis certyfikatem.

40. **EXECUTE AS** — `08-Security/02-Execute-As`  
    Zmiana kontekstu bezpieczeństwa modułu.

41. **Ownership Chaining** — `08-Security/03-Ownership-Chaining`  
    Dostęp do obiektów przez wspólnego właściciela i moduł.

42. **Separate Migration and Runtime Accounts** — `08-Security/06-Separate-Migration-Runtime`  
    Oddzielne konta do migracji i pracy aplikacji.

43. **Least Privilege** — `08-Security/07-Least-Privilege`  
    Minimalny zestaw uprawnień wymagany do wykonania zadania.

44. **Dynamic Data Masking** — `08-Security/05-Dynamic-Data-Masking`  
    Maskowanie danych dla użytkowników bez odpowiedniego uprawnienia.

45. **Column-Level Encryption** — `08-Security/09-Column-Encryption`  
    Szyfrowanie wartości wybranych kolumn.

46. **Queue Table Pattern** — `07-Performance/14-Queue-Table`  
    Tabela wykorzystywana jako kontrolowana kolejka pracy.

47. **Queue-Based Serialization** — `05-Concurrency-Integrity/09-Queue-Serialization`  
    Sekwencyjne przetwarzanie operacji konfliktujących.

48. **Append-Only Model** — `03-History-Audit/06-Append-Only`  
    Dane są dopisywane, a nie aktualizowane.

49. **Event Sourcing** — `03-History-Audit/07-Event-Sourcing`  
    Stan encji wynika z sekwencji zdarzeń.

50. **Snapshot Pattern** — `03-History-Audit/08-Snapshot`  
    Okresowy zapis stanu skracający odtwarzanie historii.

51. **Saga Pattern** — `06-Integration/06-Saga`  
    Koordynowanie wieloetapowego procesu bez jednej transakcji rozproszonej.

52. **Compensating Transaction** — `06-Integration/07-Compensating-Transaction`  
    Odwracanie efektów zakończonych kroków procesu.
