# Snapshot: filozofia, praktyka, pułapki

## Najważniejsze fakty
- Snapshot to **logiczny obraz** bazy w czasie utworzenia, realizowany przez **copy‑on‑write**.
- W chwili utworzenia **nie kopiuje** danych — rośnie tylko, gdy *baza źródłowa modyfikowana*.
- Rozmiar snapshotu ≈ suma **oryginalnych stron** (8 KB) zachowanych **przed nadpisaniem** w bazie.
- Jeden zapis w bazie może zasilić **wiele snapshotów** — każdy snapshot trzyma **własną** kopię starej strony.
- Jeśli snapshot się **zapełni** → stan **suspect**; baza źródłowa działa, snapshot do wyrzucenia.

## Zasady praktyczne
1. **Planowanie miejsca:** startowo licz **15–30%** rozmiaru bazy na kilka godzin życia snapshotu w OLTP.
2. **Czas życia:** im dłużej snapshot żyje, tym więcej zmian przechwyci → większy plik.
3. **Aktywność zapisu:** ETL, masowe UPDATE/DELETE, **online index rebuild** – to „pompy” rozmiaru.
4. **Monitoring:** mierz rozmiar plików snapshotu oraz Version Store/tempdb (DMV w `04_MonitorGrowth.sql`).
5. **Higiena:** po użyciu snapshot **usuń**. To nie jest backup ani długotrwała archiwizacja.

## Częste nieporozumienia
- „Snapshot musi mieć tyle miejsca co baza” → **fałsz** (chyba że zmienisz prawie wszystko).
- „Snapshot to backup” → **fałsz**. Snapshot wymaga **bazy źródłowej** i **tego samego serwera**.
- „NOLOCK daje to samo co snapshot” → **fałsz**. NOLOCK = brudne odczyty; snapshot = spójny obraz.

## Co mierzyć
- Rozmiar pliku snapshotu (`sys.database_files` / `sys.master_files`).
- Wskaźniki tempdb (Version Store): `sys.dm_db_file_space_usage`, `sys.dm_tran_version_store_space_usage`.
- Długo żyjące transakcje blokujące zwalnianie wersji.

Dbaj o tempdb jak o płuca serwera: szybki I/O, kilka plików, stałe monitorowanie.
