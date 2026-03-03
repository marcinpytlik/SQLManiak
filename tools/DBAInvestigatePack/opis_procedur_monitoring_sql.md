# Procedury składowane do monitorowania SQL Server - opis

Poniżej znajdziesz krótki, praktyczny opis każdej procedury: po co jest, co pokazuje i kiedy najlepiej jej używać.

## 1. `dbo.usp_DBA_CheckBlockingForDatabase`

### Do czego służy
To jest szybka procedura incydentowa do sprawdzania bieżącego blokowania w jednej bazie.

### Co sprawdza
- czy w bazie występuje blokowanie,
- czy widać waity `LCK_M_%`,
- czy występuje `WRITELOG`,
- kto blokuje kogo,
- czy problem wygląda bardziej na locki, log, albo miks obu.

### Co zwraca
1. **Szybkie podsumowanie** - 1 wiersz z polami typu:
   - `HasBlocking`
   - `BlockedSessions`
   - `BlockerSessions`
   - `HasWriteLog`
   - `MaxWriteLogWaitMs`
   - `MaxLckWaitMs`
   - `HasTmRequest`
2. **Aktywne requesty** - sesje, komendy, waity, `wait_resource`, SQL batch i aktualna instrukcja.
3. **Lancuch blokowania** - ofiary, blockerzy i ewentualnie blocker spoza analizowanej bazy.
4. **Locki** - tryb locka, status (`GRANT`, `WAIT`, `CONVERT`) i typ zasobu.
5. **I/O plików** - data/log i opoznienia odczytu/zapisu.
6. **Otwarte transakcje** - czas startu transakcji i zuzycie logu.

### Kiedy używać
- gdy aplikacja "wisi",
- gdy `UPDATE`/`INSERT` stoją,
- gdy chcesz szybko złapać aktywny problem.

### Przykladowe użycie
```sql
EXEC master.dbo.usp_DBA_CheckBlockingForDatabase
    @DbName = N'ws_PO',
    @OnlyBlocked = 1,
    @MinWaitMs = 1000;
```

---

## 2. `dbo.usp_DBA_BaselineSingleDatabase`

### Do czego służy
To jest pełny baseline jednej bazy - techniczny przeglad kondycji bazy w jednym przebiegu.

### Co sprawdza
- konfigurację bazy,
- pliki i autogrowth,
- I/O plików,
- VLF w logu,
- wait stats instancji,
- aktywne requesty,
- blokowanie,
- locki,
- transakcje,
- najciezsze zapytania z cache,
- Query Store (jeśli jest włączony).

### Co zwraca
1. **Summary** - szybki stan: blokowanie, `WRITELOG`, liczba `TM REQUEST`.
2. **Informacje o bazie** - recovery model, compatibility level, `log_reuse_wait_desc`, ustawienia statystyk.
3. **Pliki bazy** - data/log, rozmiar, autogrowth, max size.
4. **I/O plików** - srednie opóźnienia dla data i log.
5. **VLF summary** - liczba VLF, aktywne VLF, rozmiary.
6. **Wait stats** - top waity dla całej instancji.
7. **Aktywne requesty** - bieżące sesje tej bazy.
8. **Blokowanie** - sesje biorące udział w chainie.
9. **Locki** - locki dla tej bazy.
10. **Otwarte transakcje** - aktywne transakcje powiązane z sesjami w bazie.
11. **Top cached queries** - najcięższe zapytania z cache.
12. **Query Store status** - stan Query Store.
13. **Top Query Store queries** - historycznie najcięższe zapytania (gdy QS jest aktywny).

### Kiedy używać
- gdy chcesz zrobić ogólny przeglad bazy,
- przed i po zmianach,
- po incydencie,
- do szybkiego baseline porównawczego.

### Przykladowe użycie
```sql
EXEC master.dbo.usp_DBA_BaselineSingleDatabase
    @DbName = N'ws_PO',
    @OnlyActiveIssues = 1,
    @TopN = 20;
```

---

## 3. `dbo.usp_DBA_KeyLockMapForDatabase`

### Do czego służy
Ta procedura mapuje locki `KEY` i waity `LCK_M_%` do konkretnej tabeli i indeksu.

### Co sprawdza
- za jakim obiektem stoi `KEY:%`,
- który indeks bierze udział w contention,
- które sesje są w konflikcie,
- jaki SQL stoi za lockiem.

### Co zwraca
1. **Szczegóły sesji i locków**:
   - `session_id`
   - `blocking_session_id`
   - `wait_type`
   - `wait_resource`
   - `resource_type`
   - `request_mode`
   - `request_status`
   - `schema_name`
   - `object_name`
   - `index_name`
   - SQL batch i aktualna instrukcja
2. **Agregacja po obiekcie** - które obiekty i indeksy pojawiają się najczęściej.

### Kiedy używać
- gdy widzisz `LCK_M_U`, `LCK_M_X`,
- gdy `wait_resource` wygląda jak `KEY:%`,
- gdy chcesz ustalić konkretną tabelę i indeks odpowiedzialne za blokowanie.

### Przykladowe użycie
```sql
EXEC master.dbo.usp_DBA_KeyLockMapForDatabase
    @DbName = N'ws_PO',
    @OnlyWaiting = 0;
```

Albo dla konkretnego SPID:

```sql
EXEC master.dbo.usp_DBA_KeyLockMapForDatabase
    @DbName = N'ws_PO',
    @SessionId = 231;
```

---

## 4. `dbo.usp_DBA_PageLatchHotspotForDatabase`

### Do czego służy
Ta procedura służy do analizy problemów typu `PAGELATCH_*`, czyli contention na stronach w pamięci.

### Co sprawdza
- `PAGELATCH_SH`,
- `PAGELATCH_EX`,
- `PAGELATCH_UP`,
- które strony są "gorące",
- które sesje o nie walczą.

### Co zwraca
1. **Szczegóły sesji** - kto czeka, na jakim `wait_type`, na jakim `wait_resource`, z jakim SQL.
2. **Agregacja po `wait_resource`** - najgorętsze strony, liczba oczekujących sesji, max i avg wait.
3. **Agregacja po typie waita** - ile jest `PAGELATCH_SH`, `PAGELATCH_EX`, `PAGELATCH_UP`.

### Kiedy używać
- gdy w waitach widzisz `PAGELATCH_*`,
- gdy podejrzewasz hot page,
- gdy masz dużo równoległych insertów/update'ów w ten sam obszar.

### Przykladowe użycie
```sql
EXEC master.dbo.usp_DBA_PageLatchHotspotForDatabase
    @DbName = N'ws_PO',
    @MinWaitMs = 1;
```

---

## 5. `dbo.usp_DBA_PageResourceToObject`

### Do czego służy
Ta procedura mapuje konkretną stronę (`dbid:fileid:pageid`) do obiektu w bazie.

### Co sprawdza
- jaki obiekt stoi za `wait_resource` typu:
  - `8:1:7205`
  - `PAGE: 8:1:7205`
- jaki to indeks,
- jaki to typ strony,
- czy są aktywne sesje czekające dokładnie na tę stronę.

### Co zwraca
1. **Summary parsowania** - co podałeś, co zostało sparsowane, `file_id`, `page_id`, zgodność `dbid`.
2. **Mapowanie strony** - `schema_name`, `object_name`, `index_name`, `page_type_desc`, allocation unit.
3. **Aktywne sesje czekające na tę stronę** - bieżące requesty powiązane dokładnie z tym `wait_resource`.

### Kiedy używać
- gdy masz konkretny `wait_resource`,
- gdy analizujesz `PAGELATCH_*`,
- gdy chcesz przejść z "gorąca strona" do "konkretna tabela i indeks".

### Przykladowe użycie
```sql
EXEC master.dbo.usp_DBA_PageResourceToObject
    @DbName = N'ws_PO',
    @WaitResource = N'8:1:7205';
```

Albo automatycznie z aktywnego SPID:

```sql
EXEC master.dbo.usp_DBA_PageResourceToObject
    @DbName = N'ws_PO',
    @SessionId = 240;
```

---

# Szybka ściąga - co odpalić kiedy

## Gdy użytkownik mówi: "system stoi"
Użyj:
- `usp_DBA_CheckBlockingForDatabase`

## Gdy chcesz pełny przegląd bazy
Użyj:
- `usp_DBA_BaselineSingleDatabase`

## Gdy widzisz `KEY` / `LCK_M_U` / `LCK_M_X`
Użyj:
- `usp_DBA_KeyLockMapForDatabase`

## Gdy widzisz `PAGELATCH_*`
Użyj:
- `usp_DBA_PageLatchHotspotForDatabase`

## Gdy masz konkretną stronę i chcesz wiedzieć, co to jest
Użyj:
- `usp_DBA_PageResourceToObject`

---

# Zalecana kolejność podczas incydentu

1. **Szybki obraz**
```sql
EXEC master.dbo.usp_DBA_CheckBlockingForDatabase
    @DbName = N'ws_PO',
    @OnlyBlocked = 1,
    @MinWaitMs = 1000;
```

2. **Pełniejszy kontekst**
```sql
EXEC master.dbo.usp_DBA_BaselineSingleDatabase
    @DbName = N'ws_PO',
    @OnlyActiveIssues = 1;
```

3. **Jesli są `KEY` / `LCK_M_%`**
```sql
EXEC master.dbo.usp_DBA_KeyLockMapForDatabase
    @DbName = N'ws_PO',
    @OnlyWaiting = 0;
```

4. **Jesli są `PAGELATCH_*`**
```sql
EXEC master.dbo.usp_DBA_PageLatchHotspotForDatabase
    @DbName = N'ws_PO',
    @MinWaitMs = 1;
```

5. **Jesli masz konkretną gorącą stronę**
```sql
EXEC master.dbo.usp_DBA_PageResourceToObject
    @DbName = N'ws_PO',
    @WaitResource = N'8:1:7205';
```
