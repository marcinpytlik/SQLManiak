# SQLManiak — standard publikacji laboratoriów

Wersja 1.0 | Uzgodniono 2026-11-26

## Zakres
Standard obowiązuje dla nowych laboratoriów cyklu „EF Core oczami DBA” oraz związanych z nimi artykułów i materiałów szkoleniowych. Lab 68 stanowi pierwszy wzorzec. Dostosowanie innych technologii do charakteru eksperymentu jest dopuszczalne, ale odstępstwa należy udokumentować.

## Struktura referencyjna
```text
LabXX/
  Program.cs
  compose.yaml
  README.md
  RESULTS.md
  Invoke-LabXX.ps1
  observe.sql
  data/
    measurements.csv
  charts/
    Export-Charts.py
    figures/
      figure-01.svg
      figure-01.png
```
Dodatkowe skrypty SQL, XE i pliki projektowe według potrzeb.

## Metodyka
- Zdefiniować problem, hipotezę, scenariusz bazowy i kontrolny (gdy ma zastosowanie).
- Zapisać wersje silnika, CU/build, runtime, pakietów, narzędzi, konfigurację i datę pomiarów.
- Używać odizolowanego środowiska Docker Compose i automatyzacji PowerShell; diagnostyka SQL przez sqlcmd.
- Dokumentować sposób pomiaru, jednostki, rozdzielczość próbkowania, ograniczenia i wyniki negatywne.
- Ujednolicić czas do UTC; zachować informację o strefie źródłowej.
- Rozdzielać hipotezy, obserwacje i interpretacje. Nie utożsamiać braku obserwacji z dowodem braku zjawiska.
- Każdy opublikowany wynik liczbowy musi mieć odzwierciedlenie w danych źródłowych lub jawnie opisanym obliczeniu na ich podstawie.
- Nie publikować haseł, danych klientów, produkcyjnych identyfikatorów ani niezanonimizowanych logów.

## Dane i dokumentacja
README.md zawiera instrukcję uruchomienia, wymagania, scenariusze i sprzątanie. RESULTS.md zawiera rzeczywiste wyniki, status testów i ograniczenia. CSV przechowuje dane pomiarowe z opisanymi kolumnami i jednostkami; dane odtworzone z logów należy oznaczać jako ekstrakcję, a nie surowy eksport. Logi robocze, sekrety i artefakty kompilacji wykluczyć z Git.

## Ilustracje
- Wykresy generować programowo, preferowany Python/Matplotlib; skrypt i dane wersjonować razem.
- SVG na blog, PNG 1600 × 900 do LinkedIn i materiałów szkoleniowych.
- Angielskie opisy techniczne wspólne dla PL/EN/DE.
- Kolorystyka: czerwony — blokowanie i timeout; zielony — recovery i prawidłowe działanie; pomarańczowy — transakcje i ostrzeżenia; niebieski — aplikacja i architektura; szary — kontekst.
- Stopka: SQLManiak | EF Core through the eyes of a DBA | Lab XX.
- Numeracja ilustracji, opis osi i jednostek, legenda, czytelność także bez rozróżniania kolorów.
- Skale logarytmiczne oznaczać jawnie. Diagramy poglądowe i rekonstrukcje odróżniać od wykresów pomiarowych. Nie generować danych ani wykresów pomiarowych przez generatory obrazów AI.

## Artykuł
Trzy osobne wersje: PL, EN, DE. Układ: problem produkcyjny, hipoteza, środowisko, metodyka, eksperymenty, wyniki, interpretacja, rekomendacje, ograniczenia, instrukcja reprodukcji i źródła. Wersje językowe muszą zachować te same dane i wnioski. Wspólne ilustracje SVG. Materiały społecznościowe mogą używać PNG.

## Checklista przed publikacją
- [ ] Kod kompiluje się i scenariusze wykonano w labie.
- [ ] Wyniki i wersje udokumentowane.
- [ ] Dane źródłowe dostępne, bez sekretów.
- [ ] Wykresy odtwarzalne, poprawne jednostki i opisy.
- [ ] Hipotezy nie są prezentowane jako pomiary.
- [ ] Linki do kodu i źródeł poprawne.
- [ ] PL/EN/DE spójne; Hugo build zweryfikowany przed publikacją.
- [ ] Otwarte ograniczenia lub niewykonane testy jawnie wskazane.

Zmiany standardu powinny być wersjonowane w tym dokumencie.
