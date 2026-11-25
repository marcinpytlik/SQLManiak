# SQLManiak DHC v1.7 — audyt bazowego SQL v1.5 CSV

**Data:** 25.11.2026 | **Zakres:** statyczny przegląd 862 linii załączonego pliku i porównanie z `03_Run-DHC-v1_7.ps1` na master (stan odczytany podczas audytu). Nie wykonywano SQL na serwerze ani pełnego testu PowerShell. Numery linii odnoszą się do oryginalnego SQL, chyba że wskazano PS.

## 1. Identyfikacja i werdykt

Plik: `SQLManiak_Daily_Health_Check_v1_5_CSV.sql` (załącznik z sufiksem `(3)`). SHA256: `8978B06A630F24D672EDD78721B1B8A4A84DD6CCC724B9B87DF4DBB847DA67B8`. Zgodny z sumą podaną przez operatora dla obu lokalnych kopii. UTF-8 z BOM. Nie zmieniono pliku.

**Publikacja: PASS w zakresie statycznego przeglądu zawartości.** Nie znaleziono osadzonych sekretów, adresów IP, konkretnych nazw hostów ani baz biznesowych. **Produkcja: warunkowy GO dla kontrolowanego pilotażu 2022 z kolektorem v1.7, po spełnieniu bramek poniżej.** Nie rekomenduje się samodzielnego uruchamiania legacy SQL jako zamiennika kolektora. SQL 2019 pozostaje poza zweryfikowanym zakresem. Brak stwierdzonych CRITICAL nie jest gwarancją braku wad.

## 2. Rejestr znalezisk

| ID | Waga | Linie | Znalezisko i działanie |
|---|---|---|---|
| A01 | HIGH | 519–615 | SaveHistory=0 wyłącza zapis, ale nie odczyt lokalnego hc. Istnienie hc.Sample może zmienić kontrakt z 17 na 19 wyników, jeśli wszystkie sekcje się powiodą; 03 oczekuje jednego HISTORY o kolumnach Section,Message. Przed pilotem sprawdzić brak legacy hc.Sample na źródłach. Docelowo wyłączyć lokalną sekcję historii w sposób kontrolowany, zachowując kontrakt. |
| A02 | HIGH | 612–614 | CATCH historii może wycofać całą transakcję wywołującego, nawet gdy SaveHistory=0. W v1.7 źródło jest odpytywane poza transakcją repozytorium; nie uruchamiać standalone w cudzej transakcji. Docelowo zarządzać tylko własną transakcją. |
| A03 | HIGH | 87–125, 618–728 | Legacy ERRORLOG może odpytywać nieistniejące archiwa; Default Trace wymaga dodatkowych praw i ma ograniczoną historię. 03 zastępuje obie sekcje in-memory (enumeracja archiwów i XE); stosować aktualny wrapper, nie nadawać ALTER TRACE. Nadal monitorować rotację i luki. |
| A04 | HIGH | 323–335, 122–125, 152–169, 190–201, 352–368 | Wyniki mogą zawierać tekst SQL, nazwy loginów/hostów, ścieżki plików, treść logów i jobów. Ograniczyć dostęp do JSON i alertów, zabezpieczyć backupy, nie publikować wyników. |
| A05 | HIGH | 417–500, 194–199, 245–268 | Analiza harmonogramów generuje do 2880 kombinacji na aktywny harmonogram przed filtrami; wielokrotne odwołania do sysjobhistory z funkcją agent_datetime i trzy agregacje backupset per baza mogą kosztować CPU, IO i tempdb na dużym msdb. Nie zakładać kosztu na podstawie Docker. Zmierzyć czas, logical reads i blokady na pilocie. |
| A06 | MEDIUM | 144–161, 486–490 | Activity wybiera ostatni rekord per job, nie filtruje do aktualnej sesji Agenta. Stary niedomknięty przebieg może wyglądać na RUNNING i ukrywać missed jobs. Docelowo filtr aktualnej sesji Agent; oznaczać wynik jako heurystyczny. |
| A07 | MEDIUM | 473–500 | Jedno wykonanie może pokryć kilka slotów w tolerancji ±15 min; dowolny aktualny RUNNING ukrywa wszystkie sloty joba. Nakładające się harmonogramy, zmiany harmonogramów i DST zniekształcają wnioski. Nie traktować jako dowodu braku wykonania. |
| A08 | MEDIUM | 352–364, 546–554, 687–691 | Widoczność metadanych i zależności #CurrentFiles/#Volumes; catch nie gwarantuje, że każdy błąd kompilacji zależnej tabeli będzie przechwycony. 03 zabezpiecza #Jobs, nie wszystkie pozostałe zależności. Testować brak dostępu i zachowanie PARTIAL/FAILED. |
| A09 | MEDIUM | 245–291 | Backupset według nazwy i typu, nie identyfikatora konkretnej inkarnacji bazy, bez rozróżnienia copy-only i bez weryfikacji odtwarzalności. Progi 26h/30min sztywne. Ocenić zgodność z politykami, nie traktować jako dowodu poprawnego łańcucha backupów. |
| A10 | MEDIUM | 87–138 | Maks. trzy archiwa domyślnie, 200 zwracanych wpisów, dopasowania tekstowe mogą dać false positive lub pominąć zdarzenia. 03 nadal ogranicza liczbę archiwów i zapisuje tylko wyświetlane wpisy; nie jest pełnym log shipping ani SIEM. |
| A11 | MEDIUM | 303, 745–746, 779–806 | DBCC SQLPERF(LOGSPACE) wykonywany dwukrotnie; VLF odczytywane per kandydat. Diagnostyka obserwacyjna, możliwy koszt przy licznych bazach/VLF. Brak VLF jest jawnie UNAVAILABLE; nie oznacza zera. Docelowo współdzielić próbkę logu, po testach kontraktu. |
| A12 | MEDIUM | 13–14, 417–471 | Czas lokalny i dwa dni kalendarzowe; 24h wokół DST może nie odpowiadać 24h rzeczywistym. Repo UTC, XE rewrite UTC; nie traktować wszystkich znaczników legacy jako UTC. |
| A13 | MEDIUM | 25, 588–605 | Trzy trwałe INSERT do hc tylko przy SaveHistory=1 i obecnej historii. 03 wymusza dokładnie jedną deklarację =0. Nie nadawać kolektorowi uprawnień do zapisu hc. |
| A14 | MEDIUM | 244–295, 70–85, 297–319, 779–805 | Potrzebny rzeczywisty test praw do msdb.backupset, DMV, ERRORLOG i VLF. Granty 38 nie gwarantują kompletności na każdym źródle. Część CATCH może zwrócić WARNING zamiast pełnych danych; 03 sprawdza kontrakt i wybrane frazy błędów, nie każdy semantyczny brak. |
| A15 | LOW | 23, 39–40 | Komentarz sugeruje 0=current, lecz dozwolone 1–7; parametr oznacza liczbę plików. Poprawić dokumentację przy kolejnej wersji. |
| A16 | LOW | 30, 521–603 | @HistoryDatabase zadeklarowana, ale nieużywana: nazwa bazy hc jest zakodowana na stałe. Nie traktować jako przełącznika lokalizacji. |
| A17 | LOW | 350–378, 730–832 | Oceny autogrowth i oversizing są heurystyką; celowo nie wykonują shrink ani zmian plików. Nie automatyzować rekomendacji bez danych o obciążeniu, restore i wzroście. |
| A18 | INFO | 53–64, 530–544, 606–609 | FCI odczytuje aktywny węzeł; porównanie legacy tylko przy dostępnej historii hc. Sam snapshot nie rekonstruuje wszystkich failover. Centralna historia pozwala porównywać ActiveNode, ale nie dowodzi pełnej historii przełączeń. |

## 3. Operacje modyfikujące i dynamiczny SQL

W źródle jedyne trwałe operacje DML to trzy INSERT z A13. Pozostałe CREATE TABLE, SELECT INTO, INSERT i UPDATE dotyczą tabel tymczasowych (#Alerts, #Jobs, #LogOversize itd.). Brak wykonywalnych DROP, ALTER, DELETE, TRUNCATE, KILL, BACKUP, SHRINK, zmian SQL Agent. BEGIN/COMMIT/ROLLBACK występują w sekcji historii. Zapisy w tempdb nadal zużywają zasoby. Dwa EXEC ze stałym tekstem DBCC SQLPERF(LOGSPACE) oraz wywołanie xp_readerrorlog z parametrami nie sklejają danych użytkownika; nie stwierdzono w nich wektora SQL injection. Odczyt trace korzysta z ścieżki pobranej z sys.traces. W 03 dodatkowy TRUNCATE dotyczy wyłącznie #ArchiveErrorLogRaw.

## 4. Kontrakt i integracja v1.7

Sprawdzono dziewięć kotwic regex z aktualnego 03 (normalizacja końców linii do LF na potrzeby statycznego testu Python): deklaracja SaveHistory, ERRORLOG, autogrowth, sześć kotwic JOBS. Każda występuje dokładnie raz. Jest to test strukturalny kotwic, nie wykonanie .NET Regex i całej transformacji w PowerShell. 03 wymusza SaveHistory=0, zastępuje ERRORLOG, Default Trace i zależność #Jobs. Usuwa znaną informacyjną zachętę do instalowania hc z transportowanego SUMMARY (COUNTS pochodzi z oryginalnego SQL i może zachować liczbę INFO).

| Indeks | Wynik | Linie SQL |
|---:|---|---|
|1|INSTANCE|55–64|
|2|SERVICES|72–74|
|3|ERRORLOG|122–125|
|4|JOBS_CURRENT|172–176|
|5|JOBS_STEPS|190–201|
|6|DISK_VOLUMES|225–232|
|7|DATABASES_BACKUPS|246–271|
|8|TRANSACTION_LOG|305–308|
|9|BLOCKING|323–338|
|10|FILES_AUTOGROWTH|352–368|
|11|MISSED_JOBS|475–503|
|12|SCHEDULE_DIAGNOSTICS|390–415,505–506|
|13|HISTORY (Section,Message, gdy brak hc.Sample)|521–527|
|14|AUTOGROWTH_EVENTS (przepisane na XE)|693–698|
|15|LOG_OVERSIZING|811–821|
|16|SUMMARY|840–843|
|17|COUNTS|845–849|

Kolumny statycznie odpowiadają kontraktowi w 03 dla ścieżki bez hc.Sample. Gdy hc istnieje, zamiast HISTORY mogą pojawić się trzy różne result sety (556,578,606). Nieznane/duplikaty kolektor oznacza jako anomalię; nie należy obchodzić kontraktu. Nie potwierdzono runtime typów danych ani wykonania na 2019. Testy operatora z wcześniejszej sesji Docker wspierają ścieżkę bez hc, nie wszystkie warianty.

## 5. Wymagania i bramki produkcyjne

- SQL Server 2022: źródłowe konto SQL, granty z 38, sesja XE z 39, odczyt 40; bez ALTER TRACE. Zbadać rzeczywiste uprawnienia do backupset, sys.master_files, DMV i wszystkich ONLINE baz. Nie nadawać sysadmin. SQLAgentReaderRole dziedziczy SQLAgentUserRole i nie jest formalnym całkowicie read-only kontem.
- SQL Server 2019: osobna walidacja kompatybilności, uprawnień, XE i wyników; nagłówek skryptu i instalatory wskazują 2022+. Nie obiecywać zgodności tylko dlatego, że część DMV istnieje w 2019.
- Na źródle jako DBA: `SELECT OBJECT_ID(N'SQLManiakHealthHistory.hc.Sample',N'U') AS LegacyHistoryObjectId;` Oczekiwane NULL; sprawdzić również istnienie bazy i schematu z uprawnionego kontekstu. Nie usuwać hc tylko dla zgodności. Na repozytorium v1.7 schema dhc jest odrębna.
- Host kolektora: sprawdzić SHA256, zaufany TLS, rzeczywiste poświadczenia, pasywny Linked Server, brak równoległych kolekcji. Nie wykonywać bezpośrednio SQL wewnątrz otwartej transakcji DBA.
- Pierwszy pilot: 17 głównych zestawów, kompletność metadanych i backupów, brak niewyjaśnionych PARTIAL/FAILED, koszt i czas odczytów na dużym msdb, analiza XEL. Nie interpretować COMPLETE jako brak problemów. Nie inicjować failover ani wymuszonego autogrow.
- Zachować niezmieniony plik w Git po zatwierdzeniu; uwzględnić normalizację EOL przez Git (SHA256 dotyczy dokładnych bajtów, w tym BOM i CRLF/LF). Aktualizację kodu, dokumentacji i sumy kontrolnej realizować przez PR. Nie dołączać ../install.sql ani .env. Ten audyt nie wykonał commit/push ani zmian w bazach.

## 6. Rekomendacja

Dopuścić publikację niezmienionej wersji w PR #143 po decyzji właściciela. Ujednolicić README, ARCHITECTURE i PRODUCTION_DEPLOYMENT po faktycznym dodaniu pliku. Nie przebudowywać SQL przed pilotażem bez potrzeby: najpierw sprawdzić bramki A01–A05 i koszty. Osobno zaplanować usunięcie zależności legacy hc oraz poprawki heurystyki Agent, jeśli pilot uzasadni zmiany. Nie deklarować pełnej gotowości produkcyjnej ani kompletności audytu bezpieczeństwa na podstawie statycznego przeglądu.
