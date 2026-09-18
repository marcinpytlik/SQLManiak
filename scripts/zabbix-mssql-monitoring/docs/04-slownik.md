# Słownik pojęć i skrótów

Ten słownik uzupełnia dokumentację monitoringu MSSQL w Zabbixie. Nazwy techniczne, klucze itemów, makra, nazwy DMV i komunikaty Zabbixa pozostają w oryginalnym brzmieniu, natomiast ich znaczenie opisujemy po polsku.

| Skrót / pojęcie | Rozwinięcie | Znaczenie w naszym monitoringu |
|---|---|---|
| **E2E** | *End-to-End* | Test całej ścieżki monitoringu: Zabbix Server/Proxy → `zabbix_get` → Zabbix Agent 2 → plugin MSSQL → SQL Server → wykonanie zapytania → odpowiedź. Dzięki temu sprawdzamy nie tylko otwarty port, ale działanie całego toru. |
| **MAD** | *Median Absolute Deviation* | Mediana bezwzględnych odchyleń od mediany. Odporna na pojedyncze skoki miara rozrzutu. Używamy jej przy `mssql.e2e.baseline.mad24h` i do wyliczania wskaźnika anomalii. |
| **Baseline** | linia bazowa / poziom odniesienia | Typowe zachowanie metryki wyliczone z historii. Dla E2E mamy m.in. średnią 1h, średnią 24h oraz sezonowy baseline 7d. |
| **Anomaly score** | wskaźnik anomalii | Liczba opisująca, jak mocno aktualna wartość odbiega od typowego zachowania. W v1.6 dla E2E korzysta z różnicy względem średniej 24h oraz MAD. |
| **Seasonal baseline** | sezonowa linia bazowa | Porównanie bieżącej pory z podobnymi okresami z poprzednich dni. W Zabbixie wykorzystujemy `baselinewma()` i `baselinedev()`. |
| **LLD** | *Low-Level Discovery* | Mechanizm automatycznego wykrywania obiektów w Zabbixie. Dzięki LLD tworzymy itemy i triggery np. osobno dla każdej bazy, joba, repliki AG czy filegroupy. |
| **Item** | element danych | Metryka zbierana i przechowywana przez Zabbixa, np. `mssql.cpu.sql_utilization`. |
| **Item prototype** | prototyp itemu | Wzorzec itemu tworzony dynamicznie przez LLD, np. osobny `VLF count` dla każdej wykrytej bazy. |
| **Trigger** | warunek alarmowy | Reguła określająca, kiedy Zabbix ma zgłosić problem. |
| **Trigger prototype** | prototyp triggera | Wzorzec triggera tworzony dynamicznie przez LLD dla odkrytych obiektów. |
| **Dependent item** | item zależny | Item, który nie wykonuje osobnego odpytywania SQL. Pobiera wartość z master itemu i wyciąga ją przez preprocessing. |
| **Calculated item** | item obliczany | Item wyliczany przez Zabbixa na podstawie innych danych, np. ratio, `timeleft()`, względne CPU czy baseline. |
| **Custom query** | własne zapytanie SQL | Plik `.sql` wykonywany przez plugin MSSQL Zabbix Agent 2 za pomocą `mssql.custom.query[...]`. |
| **External check** | zewnętrzny test | Skrypt uruchamiany przez Zabbix Server/Proxy. U nas służy do pełnego testu E2E. |
| **Simple check** | prosty test sieciowy | Test wykonywany przez Zabbix Server/Proxy bez agenta, np. dostępność portu TCP i czas zestawienia połączenia. |
| **AG** | *Availability Group* | SQL Server Always On Availability Group. Szablon wykrywa grupy, repliki, role, stany i synchronizację. |
| **WSFC** | *Windows Server Failover Cluster* | Klaster Windows używany m.in. przez AG i FCI. W szablonie monitorujemy quorum i członków quorum. |
| **FCI** | *Failover Cluster Instance* | Klasterowana instancja SQL Server działająca na WSFC ze współdzielonym storage. Nie jest tym samym co AG. |
| **TDE** | *Transparent Data Encryption* | Szyfrowanie plików bazy danych w SQL Server. Monitorujemy stan TDE per baza oraz liczbę baz bez szyfrowania. |
| **DEK** | *Database Encryption Key* | Klucz szyfrowania bazy używany przez TDE. Brak rekordu DEK oznacza u nas stan `0 / no DEK`. |
| **VLF** | *Virtual Log File* | Wewnętrzny fragment pliku dziennika transakcyjnego. Monitorujemy liczbę VLF per baza oraz maksimum na instancji. |
| **PLE** | *Page Life Expectancy* | Liczba sekund, przez które strona danych pozostaje średnio w buffer pool bez ponownego użycia. Jest jednym z sygnałów presji pamięciowej. |
| **DMV** | *Dynamic Management View* | Systemowy widok SQL Server dostarczający dane diagnostyczne, np. `sys.dm_db_log_info`, `sys.dm_io_virtual_file_stats`. |
| **CPU** | *Central Processing Unit* | Obciążenie procesora. Rozróżniamy CPU SQL Server, inne procesy, widoczne schedulery i CPU per baza. |
| **I/O** | *Input/Output* | Operacje wejścia/wyjścia, głównie storage. Monitorujemy m.in. read/write stall i operacje odczytu/zapisu. |
| **ms/op** | milisekundy na operację | Jednostka używana przy latencji I/O. `read_stall_ms` i `write_stall_ms` pokazują średni czas oczekiwania na pojedynczą operację. |
| **SOS_SCHEDULER_YIELD** | typ oczekiwania SQL Server | Wait sygnalizujący, że worker zużył przydzielony quantum CPU i oddał scheduler. W połączeniu z runnable queue pomaga ocenić presję CPU. |
| **Runnable tasks** | zadania gotowe do wykonania | Liczba zadań czekających na scheduler CPU. `runnable tasks per active scheduler` jest jednym z głównych sygnałów presji CPU. |
| **Memory Grants Pending** | oczekujące granty pamięci | Liczba zapytań czekających na pamięć roboczą m.in. dla sortów i hash joinów. Wartość >0 utrzymująca się w czasie może wskazywać presję pamięci. |
| **Free List Stalls** | oczekiwania na wolną stronę w buffer pool | Licznik sytuacji, w których SQL Server musiał czekać na wolną stronę pamięci. Korelujemy go z PLE, Memory Grants, Lazy Writes i Page Reads. |
| **Blocking** | blokowanie | Sytuacja, w której sesja oczekuje na zasób zablokowany przez inną sesję. W szablonie korelujemy `processes_blocked`, lock waits, lock timeouts i average wait time. |
| **Deadlock** | zakleszczenie | Cykl blokad, którego SQL Server nie może sam rozwiązać bez przerwania jednej z transakcji. |
| **SLA** | *Service Level Agreement* | W naszym kontekście oczekiwany maksymalny wiek backupu FULL/DIFF/LOG. |
| **FULL** | pełny backup | Kopia pełna bazy danych. |
| **DIFF** | *Differential backup* | Backup różnicowy zawierający zmiany od ostatniego FULL. |
| **LOG** | transaction log backup | Backup dziennika transakcyjnego dla baz w odpowiednim modelu recovery. |
| **TTL / time-to-full** | czas do zapełnienia | Prognoza czasu do osiągnięcia 100% na podstawie trendu. W `ROWS timeleft` dotyczy aktualnie zaalokowanej przestrzeni ROWS, a nie całego filesystemu. |
| **ROWS** | przestrzeń danych typu ROWS | Pliki danych i filegroupy zawierające dane wierszowe SQL Server; odróżniamy je od plików LOG. |
| **FG** | *Filegroup* | Grupa plików danych SQL Server. Monitorujemy allocated, used, free oraz used %. |
| **DB** | *Database* | Baza danych SQL Server. W nazwach itemów i makr często używamy skrótu DB. |
| **TCP** | *Transmission Control Protocol* | Protokół transportowy. Simple check sprawdza dostępność portu SQL i czas zestawienia połączenia. |
| **ODBC** | *Open Database Connectivity* | Mechanizm połączeń bazodanowych używany w pierwotnym arkuszu. W finalnym rozwiązaniu został zastąpiony przez plugin MSSQL dla Zabbix Agent 2 i custom queries. |
| **URI** | *Uniform Resource Identifier* | W makrze `{$MSSQL.URI}` wskazuje konfigurację połączenia/plugin session używaną przez Agent 2, np. `SQL3`. |
| **RPS** | *Requests Per Second* | Liczba żądań na sekundę. W części nazw i opisów Zabbixa odnosi się do częstotliwości zdarzeń/liczników. |
| **RC** | *Return Code* | Kod zakończenia polecenia. W E2E `zabbix_get_rc=0` oznacza poprawne wykonanie `zabbix_get`. |
| **UTC** | *Coordinated Universal Time* | Czas uniwersalny. `sql_utc` w E2E pochodzi bezpośrednio z SQL Servera i potwierdza wykonanie zapytania. |
| **JSON** | *JavaScript Object Notation* | Format danych zwracany przez custom queries i skrypt E2E, z którego dependent itemy wyciągają konkretne wartości. |
| **P1 / P2** | priorytet 1 / priorytet 2 | Klasy priorytetu używane w naszej macierzy alertów. P1 oznacza najważniejsze sygnały dostępności/awarii, P2 niższy priorytet diagnostyczny lub wydajnościowy. |
| **WARNING / HIGH / DISASTER** | poziomy severity Zabbixa | Poziomy ważności problemu. Pozostają w oryginalnym nazewnictwie, ponieważ odpowiadają wartościom konfiguracyjnym Zabbixa. |

## Ważna uwaga o MAD

MAD formalnie jest liczony względem **mediany**, nie względem średniej. W naszym wskaźniku anomalii 24h używamy jednak MAD jako odpornej miary rozrzutu, a odległość bieżącej wartości liczymy względem średniej 24h:

```text
abs(aktualna wartość - średnia 24h) / (MAD 24h + 1)
```

Dodanie `+1` w mianowniku zabezpiecza obliczenie przed dzieleniem przez zero, gdy historyczne wartości są bardzo stabilne.

## Jak czytać skróty w dokumentacji

Jeżeli skrót występuje jako część rzeczywistej nazwy itemu, triggera, klucza, makra albo nazwy SQL Server, pozostawiamy go bez tłumaczenia. Słownik opisuje jego znaczenie, ale nie zmienia identyfikatorów używanych w Zabbixie.