
# Szczegóły protokołu TDS (Tabular Data Stream) — praktyczny przewodnik

TDS (Tabular Data Stream) to protokół binarny używany przez SQL Server do komunikacji klient ↔ serwer. Jest podstawą wszystkich operacji sieciowych — od negocjacji połączenia, przez wysyłanie zapytań i parametrów, po strumieniowanie wyników. Poniżej znajdziesz szczegóły przydatne do debugowania, monitorowania i projektowania aplikacji.

---

## 1. Krótkie wprowadzenie — fazy komunikacji
1. **Prelogin (negocjacja)** — klient i serwer negocjują opcje (m.in. szyfrowanie).
2. **TLS handshake (opcjonalnie)** — jeśli szyfrowanie wynegocjowane, warstwa TLS ustalana przed logowaniem.
3. **Login** — sesja uwierzytelniana: login/password (SQL Auth) lub Kerberos/NTLM (Windows Auth).
4. **Normalna komunikacja** — SQL Batch / RPC / Bulk / Tabular results / Attention / Transaction messages.
5. **Zamykanie** — zamknięcie sesji; przy pooling zwrot do puli (`sp_reset_connection`).

---

## 2. Nagłówek pakietu TDS (podstawy — 8 bajtów)
Każdy pakiet TDS zaczyna się typowo od 8-bajtowego nagłówka:

- **Byte 0 — Type (1 byte)**
  Typ pakietu (np. Prelogin, Login7, SQL Batch, RPC, Attention, Tabular Result, Bulk, etc.).

- **Byte 1 — Status (1 byte)**
  Flagi statusu (np. czy to ostatni pakiet w wiadomości, czy to pakiet ze statusem error/attention itd.).

- **Bytes 2–3 — Length (2 bytes)**
  Całkowita długość pakietu (nagłówek + dane).

- **Bytes 4–5 — SPID (2 bytes)**
  Session/Process ID (czasem 0 dla niektórych wczesnych faz jak prelogin).

- **Byte 6 — PacketID (1 byte)**
  Numer fragmentu pakietu — używany przy podziale większych komunikatów na kolejne pakiety.

- **Byte 7 — Window (1 byte)**
  Okno/transmisja — historycznie używane do kontroli przepływu.

> Uwaga: konkretne zachowanie pól może zależeć od wersji TDS. To praktyczny opis przydatny przy analizie ruchu.

---

## 3. Prelogin — co jest negocjowane
Prelogin to wczesny komunikat wysyłany przez klienta (typ pakietu = Prelogin). Zawiera tokeny/ustawienia:

- **VERSION** — wersja klienta/protokół.
- **ENCRYPTION** — czy klient/serwer wspierają szyfrowanie i jakie są preferencje; tutaj następuje ustalenie, czy TLS będzie użyty.
- **INSTOPT / INSTANCE** — czasami nazwa instancji / ustawienia instancji.
- **THREADID / MARS / TRACEID** — dodatkowe opcje (np. MARS support) i identyfikatory.

Na podstawie odpowiedzi serwera klient decyduje, czy przeprowadzić TLS handshake przed wysłaniem poświadczeń (login).

---

## 4. TLS / szyfrowanie
- Jeżeli **ENCRYPTION** w prelogin wskazuje na użycie TLS (serwer wymaga lub akceptuje), to przed wysłaniem loginu uruchamiany jest standardowy handshake TLS.
- Gdy TLS jest aktywny, **cały login (login packet)** i dalsze pakiety są chronione.
- Jeśli TLS NIE jest użyty, mechanizmy „maskowania” hasła w niektórych starszych klientach **nie** zapewniają bezpieczeństwa — zawsze zalecane jest włączenie TLS w połączeniach produkcyjnych.

---

## 5. Login — Login7, uwierzytelnianie i poświadczenia
- Typowy klient wysyła pakiet **Login7** zawierający: nazwa użytkownika, host, aplikacja, opcje sesji i (w przypadku SQL Auth) hasło.
- Dla **Windows Authentication** następuje użycie SSPI: Kerberos (jeśli SPN ok) lub NTLM fallback. W takim przypadku mechanizm autentykacji może odbywać się poza prostym Login7 (SSPI tokeny, challenge-response).
- Po pomyślnym logowaniu serwer przydziela SPID i tworzy kontekst sesji.

---

## 6. Typy wiadomości / pakietów w normalnej komunikacji
- **SQL Batch** — surowy tekst SQL (np. `SELECT ...`).
- **RPC (Remote Procedure Call)** — wywołanie procedury składowanej lub `sp_executesql` z parametrami; powszechnie wykorzystywane przez sterowniki do wysyłania przygotowanych/parametryzowanych zapytań.
- **Tabular Result** — pakiety zawierające metadane kolumn i strumień wierszy wyników. Wyniki są strumieniowane w partiach.
- **Attention** — specjalny pakiet używany do anulowania zapytania (np. gdy klient przerwie operację).
- **Bulk Load** — pakiety używane przy masowym ładowaniu (bcp, BULK INSERT).
- **Transaction control** — komunikaty BEGIN/COMMIT/ROLLBACK, często realizowane jako zwykłe polecenia T-SQL lub RPC.

---

## 7. Fragmentacja i reasemblacja pakietów
- Większe komunikaty (np. duży SQL, parametry, albo obfite wyniki) są dzielone na wiele pakietów TDS.
- Pole **PacketID** oraz **Status (LAST/CONTINUE)** pozwalają odbiorcy złożyć kolejne fragmenty w całość.
- Z punktu widzenia aplikacji: sterownik wykonuje ponowne łączenie fragmentów i prezentuje komplet danych callerowi.

---

## 8. RPC vs SQL Batch — dlaczego to ma znaczenie
- **RPC** (używane przez sterowniki dla parametrów) przenosi typowo zdefiniowane typy danych i ułatwia przygotowanie/plan reuse.
- **SQL Batch** to surowy tekst; bardziej elastyczny, ale mniej efektywny pod kątem cache planów, jeśli parametry są wklejane jako literal.
- `sp_executesql` (wywoływane jako RPC lub Batch) pozwala na parametryzację i lepsze ponowne użycie planów.

---

## 9. Anulowanie zapytań — Attention
- Gdy klient chce przerwać zapytanie (np. timeout), wysyła pakiet **Attention**.
- Serwer interpretuje to jako prośbę o zatrzymanie bieżącej operacji na danym SPID i zwalnia zasoby (czasem potrzeba czasu na rollback).
- Attention jest niskopoziomową sygnalizacją — użyteczną w diagnostyce blokad i „stuck” queries.

---

## 10. Diagnostyka i narzędzia (praktyczne wskazówki)
- **Wireshark** — ma dissector TDS; filtrowanie po TCP porcie (`tcp.port == 1433`) i typach TDS pozwala zobaczyć prelogin/login oraz kolejne pakiety.
  - Szukaj: `Prelogin`, `Login7`, `SQL Batch`, `RPC` w kolumnie protocol.
  - Jeśli TLS aktywny, payload będzie zaszyfrowany — zobaczysz jedynie handshake TLS i zaszyfrowane pakiety.
- **Extended Events / Trace** — na poziomie serwera możesz złapać `login`, `rpc_starting`, `sql_batch_starting`, `attention` events aby korelować pakiety sieciowe z aktywnością serwera.
- **Errorlog** — komunikaty o błędach uwierzytelnienia (18456), negocjacji TLS lub o odrzuconych połączeniach.

---

## 11. Najczęstsze problemy powiązane z TDS i wskazówki
- **Brak szyfrowania + login via SQL** → ryzyko podsłuchu. Zawsze preferuj TLS (`Encrypt=True`).
- **Prelogin: server requires encryption** → klient który nie obsługuje TLS nie połączy się; patrz ustawienia prelogin `ENCRYPTION`.
- **Fragmentacja** → duże rezultaty / bulk mogą być podzielone, debuguj po stronie serwera i klienta (fetch size).
- **Attention nie przechodzi** → czasami clients/driver/niska wersja TDS mogą nie wysyłać prawidłowo; sprawdź czy timeouty i cancel tokeny są obsługiwane.
- **Kerberos/SPN issues** → Windows auth może być fallback do NTLM jeśli SPN nie skonfigurowane prawidłowo; to wpływa na uwierzytelnienie i czas.

---

## 12. Praktyczne best-practices
- Zawsze włącz **TLS** w połączeniach produkcyjnych.
- Używaj **parametryzacji / prepared statements / RPC** aby uniknąć SQL injection i poprawić reuse planów.
- Monitoruj Query Store / DMVs do korelacji planów z RPC vs Batch.
- Przy debugowaniu wykorzystaj Wireshark + Extended Events — korelacja sieć ↔ serwer daje pełny obraz.

---

## 13. Dalsze lektury (szybkie wskazówki)
- Szukaj dyskusji o "TDS packet header", "prelogin token", "Login7 packet" i "TDS RPC" w dokumentacji protokołu lub w materiałach Microsoft.
- Przy praktycznym debugu: Wireshark + Query Store + `sys.dm_exec_connections` + `sys.dm_exec_sessions` to najlepsza kombinacja.

---

_ostatnia aktualizacja: 2025-09-16
