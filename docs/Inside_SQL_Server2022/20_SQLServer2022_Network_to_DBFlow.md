# Flow: Połączenie klienta → komponent sieciowy → Database Engine → wykonanie zapytania

Ten dokument opisuje krok-po-kroku, co dzieje się gdy klient nawiązuje połączenie do SQL Server i jak zapytanie przepływa przez warstwy: network layer -> listener / browser -> database engine (relational & storage) -> execution -> wynik. Zawiera też uwagi praktyczne dotyczące named instances, TLS, SQL Browser, Always On, pooling itp.

---

Szybki diagram (tekstowy)
```
Client App
   |
   | TCP/TDS (TLS optional)
   v
Network layer / Firewall / LB
   |
   v
SQL Server Listener (TCP port)  <-- SQL Browser (UDP 1434) dla named instances
   |
   v
Database Engine Service (MSSQLSERVER / MSSQL$INST)
   - Relational Engine (Parser -> Optimizer -> Plan Cache -> Execution)
   - Storage Engine (Buffer Pool -> I/O -> Transaction Log)
   |
   v
Results (TDS) --> Client App
```

---

Szczegółowy flow krok po kroku

1) Inicjalizacja połączenia — klient
- Aplikacja tworzy połączenie przy użyciu drivera (ADO.NET / ODBC / JDBC) i connection stringa.
- Parametry: Server, Instance, Port, Encrypt, TrustServerCertificate, Application Name, Connect Timeout, MultiSubnetFailover, ReadIntent itp.

2) Transport sieciowy i discovery
- Jeśli podano nazwę instancji (named instance), klient pyta SQL Server Browser (UDP 1434) o numer portu lub o mapę endpointów. Browser odpowiada, klient łączy się pod wskazany port.
- Jeśli użyty jest listener Always On (AG) lub load balancer, klient łączy się do DNS/endpointu listenera; MultiSubnetFailover może przyspieszać failover detection.
- Firewall/load balancer musi przepuścić ruch na port (domyślnie TCP 1433) oraz UDP 1434 (jeśli używasz discovery dla named instances).

3) TLS handshaking i szyfrowanie (opcjonalnie)
- Jeśli Encrypt=True, przed uwierzytelnieniem następuje TLS handshake. Serwer wysyła certyfikat, klient waliduje (chyba że TrustServerCertificate=True).

4) Uwierzytelnienie (Authentication)
- Windows Auth (Kerberos/NTLM): Kerberos preferred; jeśli jest problem z SPN lub delegacją — może nastąpić fallback do NTLM.
- SQL Auth: login/password przesyłane przez zaszyfrowany kanał (TLS).
- Po pomyślnym uwierzytelnieniu serwer tworzy sesję i przypisuje SPID (session id).

5) Negocjacja ustawień sesji
- Serwer i klient negocjują opcje sesji: packet size, ANSI settings, language, dateformat, SET options.
- Jeśli connection pooling jest w użyciu, sterownik wykonuje sp_reset_connection na połączeniu zwróconym z puli, by wyczyścić stan sesji.

6) Routing zapytania do Database Engine
- Po ustanowieniu połączenia tekst zapytania lub polecenie przygotowane trafia do Relational Engine (parser/optimizer).
- Dedykowane połączenia administracyjne (DAC) używają prefiksu admin: lub flagi -A (czasem wymagane do diagnostyki).

7) Relational Engine — parsing i optymalizacja
- Parser: sprawdza składnię, tworzy parse tree.
- Binding: waliduje obiekty (tabele/kolumny), tworzy bound tree.
- Optymalizator: generuje plany, szacuje koszty używając statystyk.
- Plan Cache: jeśli istnieje odpowiedni plan — może zostać użyty (plan reuse).
- Kompilacja: plan fizyczny jest skompilowany i przekazany do Execution Engine.

Uwaga: parameter sniffing, plan forcing, hints, OPTION (RECOMPILE) wpływają na ten etap.

8) Execution Engine i Storage Engine — wykonanie i I/O
- Execution Engine wykonuje plan operator po operatorze (Index Seek/Scan, Hash Match, Nested Loops itd.).
- Gdy potrzeba strony danych — Storage Engine sprawdza Buffer Pool (RAM); jeśli brak, wykonuje fizyczne I/O z plików .mdf/.ndf.
- Modyfikacje zapisane są najpierw do Transaction Log (WAL) — append; log gwarantuje durability po COMMIT.
- Lock Manager / Version Store: w zależności od isolation level operacje używają locków lub wersjonowania (RCSI/SNAPSHOT).
- Operacje dodatkowe: triggery, aktualizacje indeksów, utrzymanie columnstore, statystyki (auto update) itp.

9) Generowanie wyników i przesłanie do klienta
- Wyniki są strumieniowane z Execution Engine do klienta w pakietach TDS.
- Driver odbiera pakiety i udostępnia dane jako DataReader/ResultSet.
- Dla dużych rezultatów transfer odbywa się partiami (fetching / paging).

10) Zamknięcie sesji i pooling
- Po Close() lub Dispose() połączenie zwracane jest do puli (jeśli pooling włączony) i sp_reset_connection usuwa kontekst sesji.
- Jeśli połączenie nie jest potrzebne — jest zamknięte i zasoby zwalniane.

---

Rzadsze ale ważne warianty flow
A) Dedicated Admin Connection (DAC) — połączenie DAC omija standardowe limity i pozwala na diagnostykę gdy instancja jest obciążona lub nie odpowiada. Użyj -A lub admin:. Dostępne tylko lokalnie lub jeśli skonfigurowane zdalnie.

B) Single-user mode / Recovery flags — przy starcie z -m (single-user) lub /T3608 zachowanie się serwera jest zmodyfikowane (przywracanie master lub odłączenie innych DB). Połączenia są ograniczone i trzeba odpowiednio łączyć się (często przez sqlcmd).

C) Always On Availability Groups (AG) — klient łączy się do listenera AG (DNS). Listener kieruje połączenia do primariusza (lub do secondary jeśli read-intent). MultiSubnetFailover=True pomaga skrócić reconnect time w środowiskach multi-subnet.

D) Read-Scale / Readable secondaries — Połączenia z opcją ApplicationIntent=ReadOnly mogą trafić na readable secondary (jeśli listener + routing skonfigurowane).

E) Load Balancers i firewalle — Przy frontach LB/azure load balancer -> health probes i sticky sessions mogą wpływać na routing i sesje. Upewnij się, że idle timeouts i probe interval są ustawione zgodnie z wymaganiami SQL Server (TCP keepalive, MultiSubnetFailover considerations).

---

Diagnostyka — gdzie patrzeć na poszczególnych etapach
- Network: packet capture (Wireshark, TDS filters), firewall logs, port reachability (telnet, Test-NetConnection).
- Auth: Windows event logs, SQL errorlog (18456), Kerberos SPN.
- Session: sys.dm_exec_sessions, sys.dm_exec_connections, sys.dm_exec_requests.
- Plans & Compile: sys.dm_exec_cached_plans, Query Store, sys.dm_exec_query_plan.
- I/O & Waits: sys.dm_io_virtual_file_stats, sys.dm_os_wait_stats.
- Locks & Blocking: sys.dm_tran_locks, sys.dm_exec_requests, Extended Events.
- Errorlog: SQL Server Errorlog, Windows Event Viewer.

---

Krótka checklista przy problemie
- Nie mogę połączyć się: sprawdź firewall, SQL Browser, port, listener, nazwa instancji.
- Błędy logowania: sprawdź typ uwierzytelnienia, SPN, komunikaty 18456.
- Wolne zapytania: sprawdź plan, statystyki, IO, wait stats.
- Duże opóźnienia przy failover: sprawdź MultiSubnetFailover, listener config, LB probe settings.

---

ostatnia aktualizacja: 2025-09-16
