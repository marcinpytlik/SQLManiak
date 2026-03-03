Co robi RCSI

Po włączeniu READ_COMMITTED_SNAPSHOT ON poziom izolacji READ COMMITTED przestaje czytać dane „z blokad współdzielonych”, a zaczyna czytać wersje wierszy z tempdb.

Czyli:

SELECT-y nie muszą czekać na wiele aktywnych UPDATE/DELETE/INSERT

UPDATE/DELETE rzadziej są blokowane przez zwykłe odczyty

mniej klasycznego konfliktu:

reader blokuje writera

writer blokuje readera

To jest właśnie główny zysk.

Kiedy realnie pomaga

RCSI zwykle pomaga, gdy masz:

dużo jednoczesnych odczytów i zapisów

długie raporty / odczyty na tabelach, które są modyfikowane

aplikację, która siedzi na domyślnym READ COMMITTED

problemy typu LCK_M_S, LCK_M_U, LCK_M_X

pokusę używania NOLOCK, bo „inaczej wszystko stoi”

W takich systemach RCSI często działa jak zdjęcie cegły z pedału hamulca.

Co dokładnie zmniejsza
Zmniejsza:

blokady S (shared) przy odczytach

czekanie readerów na writerów

czekanie writerów na readerów (w wielu scenariuszach)

Nie usuwa:

blokad między writerami

deadlocków wynikających z aktualizacji w różnej kolejności

problemów z fatalnym planem zapytania

problemów z brakującymi indeksami

problemów z gigantycznymi transakcjami

Czyli RCSI nie naprawia złego SQL-a. Ono tylko ogranicza jeden konkretny typ wojny.

Czy zwiększy wydajność?
Często: tak, od strony przepustowości i responsywności

Bo:

mniej czekania na locki

więcej równoległego ruchu

aplikacja szybciej dostaje odpowiedzi

Ale czasem: nie bez kosztu

Bo dochodzi:

utrzymywanie wersji wierszy

dodatkowe obciążenie tempdb

większy narzut przy modyfikacjach danych

Więc możesz zyskać:

mniej blokad

szybsze odczyty

ale zapłacisz:

większym użyciem tempdb

czasem większym I/O

większym zużyciem miejsca na version store

To jest trade-off, nie cud z telezakupów.

Największe skutki uboczne
1) tempdb dostaje więcej roboty

Bo tam trafiają wersje wierszy.
Jeśli tempdb już ledwo zipie, to po RCSI może zacząć kaszleć.

Warto obserwować:

rozmiar tempdb

autogrowth

I/O na tempdb

version store

2) Odczyt widzi ostatnią zatwierdzoną wersję

Czyli niekoniecznie „to, co właśnie ktoś zmienia w tej mikrosekundzie”.

Dla większości aplikacji to jest super.
Dla niektórych procesów biznesowych trzeba to świadomie zaakceptować.

3) Niektóre stare aplikacje miały „ukryte założenia” o blokowaniu

Na przykład liczyły, że zwykły SELECT przytrzyma coś przez locki.
Po RCSI to założenie może się rozsypać.

Czy zmniejszy ilość blokad?

Tak — głównie blokad odczytu.
To jest wręcz jego główny sens.

Ale:

writer vs writer nadal się blokują

ALTER, SCH-M, metadata locks nadal potrafią boleć

długie transakcje nadal robią syf

Więc nie „usuwa blokad”, tylko mocno redukuje część najbardziej dokuczliwych.

Kiedy bym rozważył włączenie

Jeśli widzisz:

sporo SELECT kontra UPDATE/DELETE

czekania lockowe

dużo kuszącego WITH (NOLOCK) w kodzie

OLTP z dużą współbieżnością

to RCSI jest bardzo sensownym kandydatem.

Kiedy uważać

Jeśli masz:

bardzo obciążone tempdb

długie transakcje aktualizujące masę danych

aplikację zależną od bardzo specyficznego zachowania locków

procesy ETL / maintenance robiące ciężkie modyfikacje

to trzeba testować, nie włączać na ślepo jak światła w piwnicy.

Jak włączyć
ALTER DATABASE TwojaBaza
SET READ_COMMITTED_SNAPSHOT ON
WITH ROLLBACK IMMEDIATE;

Uwaga: to może rozłączyć aktywne sesje przez WITH ROLLBACK IMMEDIATE, więc rób to w kontrolowanym oknie.

Sprawdzenie:

SELECT
    name,
    is_read_committed_snapshot_on,
    snapshot_isolation_state_desc
FROM sys.databases
WHERE name = N'TwojaBaza';
Najuczciwszy werdykt

Tak — RCSI często poprawia współbieżność i redukuje blokady, czasem bardzo wyraźnie.
Ale:

nie leczy złych planów,

nie zastępuje indeksów,

nie rozwiązuje konfliktów writer-writer,

przerzuca część kosztu do tempdb.

To jest jedno z najlepszych ustawień dla wielu systemów OLTP, ale trzeba je wdrażać świadomie, nie rytualnie.

Jeśli chcesz, mogę ci przygotować:

checklistę „czy twoja baza jest dobrym kandydatem do RCSI”,

skrypt przed/po do pomiaru blokad,

oraz plan bezpiecznego wdrożenia na SQL Server 2022.