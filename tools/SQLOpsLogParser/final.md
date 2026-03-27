# SqlOpsLogParser — opcjonalne rozszerzenia po sprintach

## Cel dokumentu

To jest lista elementów opcjonalnych, które nie były wymagane do zamknięcia sprintów, ale pozwolą zrobic wersje v2
- polishing,
- rozwinięcie,
- kolejny naturalny krok.
---

# Sprint 1 — profile i connectivity

## Opcjonalne rozszerzenia

### 1. Obsługa hasła poza `profiles.json`
Zamiast trzymać hasło jawnie w pliku:
- zmienna środowiskowa,
- Windows Credential Manager,
- zaszyfrowany secret store.

### 2. Rozpoznawanie formatu profilu po nazwie instancji / porcie
Na przykład lepsze komunikaty dla:
- `localhost`
- `localhost\SQLEXPRESS`
- `localhost,1433`

### 3. Lepsza walidacja profili
Na przykład:
- brak `userName` dla `authentication = Sql`,
- brak `password` dla `authentication = Sql`,
- ostrzeżenie przy pustym `database`.

### 4. Komenda `profiles add` / `profiles init`
Generator podstawowego pliku konfiguracyjnego.

---

# Sprint 2 — lista ErrorLogów

## Opcjonalne rozszerzenia

### 1. Lepsze sortowanie logów
Na przykład:
- bieżący log na górze,
- najnowsze archiwa malejąco.

### 2. Dodatkowe formatowanie rozmiarów
Na przykład:
- KB / MB / GB automatycznie,
- czytelniejszy formatter jednostek.

### 3. Eksport `errorlog list`
Zapis listy logów do CSV / JSON / Markdown.

---

# Sprint 3 — odczyt wpisów ErrorLog

## Opcjonalne rozszerzenia

### 1. Opcja `--full`
Bez przycinania pola `Text`.

### 2. Opcja `--desc`
Sortowanie malejąco po czasie.

### 3. Czytanie z wielu archiwów
Na przykład:
- `--logs 0,1,2`
- `--all-archives`

### 4. Lepsze parsowanie dat
Na przykład:
- jawna kultura,
- wymuszony format `yyyy-MM-dd HH:mm:ss`.

---

# Sprint 4 — klasyfikacja wpisów

## Opcjonalne rozszerzenia

### 1. Rozszerzenie reguł klasyfikacji
Dodatkowe kategorie:
- tempdb,
- latch,
- autogrowth,
- Query Store,
- TDE,
- login auditing,
- linked server,
- backup verification.

### 2. Wielowartościowe tagi zamiast jednej kategorii
Zamiast jednego `Category`:
- lista tagów,
- np. `Security + Error`,
- `Availability + Shutdown`.

### 3. Konfiguracja reguł z pliku JSON
Zamiast hardcoded reguł w klasie:
- zewnętrzny plik konfiguracyjny,
- własne wzorce użytkownika.

### 4. Lepsze mapowanie severity
Na przykład na podstawie:
- `Error: <nr>, Severity: <nr>`
- numerów błędów 823/824/825,
- parsing bardziej semantyczny niż tekstowy.

---

# Sprint 5 — joby i failed jobs

## Opcjonalne rozszerzenia

### 1. Wykrywanie Express Edition
Czytelny komunikat:
- SQL Server Agent nie jest dostępny w Express Edition.

### 2. Dodatkowe informacje o jobach
Na przykład:
- category,
- created date,
- modified date,
- notify level,
- last run outcome.

### 3. Filtrowanie `jobs list`
Na przykład:
- tylko enabled,
- tylko disabled,
- po fragmencie nazwy.

### 4. Raport „najczęściej failing jobs”
Agregacja liczby awarii per job.

---

# Sprint 6 — kroki jobów i failed steps

## Opcjonalne rozszerzenia

### 1. `jobs step-history`
Pełna historia wykonań kroków konkretnego joba.

### 2. Pokazywanie pełnego command kroku
Obecnie skracane — opcjonalnie tryb:
- `--full-command`

### 3. Mapowanie akcji `OnSuccessAction` / `OnFailAction`
Zamiast liczb:
- QuitWithSuccess
- QuitWithFailure
- GoToNextStep
- GoToStep

### 4. Rozszerzenie analizy maintenance planów
Rozpoznawanie:
- SSIS package names,
- maintenance plan step meaning,
- typ zadania backup/checkdb/reindex.

---

# Sprint 7 — timeline

## Opcjonalne rozszerzenia

### 1. Łączenie wielu archiwów ErrorLog w timeline
Nie tylko log `0`, ale też archiwa.

### 2. Lepsza deduplikacja zdarzeń
Na przykład przy zestawianiu:
- failed job
- failed step
- wpis errorlog
dla tego samego incydentu.

### 3. Dodatkowe źródła timeline
Na przykład później:
- Windows Event Log,
- SQL Agent alerts,
- backup history z `msdb`,
- Query Store alerts.

### 4. Grupowanie timeline po incydentach
Na przykład:
- okno 5 minut,
- automatyczne grupy zdarzeń.

---

# Sprint 8 — eksport raportów

## Opcjonalne rozszerzenia

### 1. `--also-print`
Jednoczesny:
- zapis do pliku,
- output do konsoli.

### 2. Rozpoznawanie formatu po rozszerzeniu pliku
Na przykład:
- `.md` => Markdown
- `.json` => JSON
- `.csv` => CSV

### 3. Lepszy Markdown writer dla zagnieżdżonych danych
Na przykład:
- sekcje,
- podsekcje,
- listy,
- bardziej czytelne raporty zamiast prostych tabel refleksyjnych.

### 4. Timestamp w nazwach plików
Automatyczne nazwy typu:
- `timeline-2026-03-27-2100.md`

### 5. Szablony raportów
Na przykład:
- minimalistyczny,
- pełny,
- executive summary.

---

# Sprint 9 — raporty operacyjne

## Opcjonalne rozszerzenia

### 1. Rozszerzony `nightly report`
Sekcje:
- Summary
- Failed Jobs
- Failed Steps
- Critical ErrorLog entries
- Timeline highlights

### 2. Rozszerzony `incident report`
Sekcje:
- Incident context
- Matching timeline events
- Failed jobs in range
- Failed steps in range
- ErrorLog correlation

### 3. Dedykowany writer dla raportów operacyjnych
Nie ogólny writer refleksyjny, tylko raport sekcyjny z ładnym układem.

### 4. Ranking najważniejszych zdarzeń
Na przykład:
- top errors,
- top categories,
- najczęściej failing job.

### 5. Executive summary
Krótki opis tekstowy generowany z danych:
- ile błędów,
- jaki job padał,
- czy były critical events.

---

# Sprint 10 — hardening i domknięcie

## Opcjonalne rozszerzenia

### 1. `--verbose`
Więcej szczegółów na konsoli:
- aktywne filtry,
- liczba rekordów,
- czas wykonania.

### 2. `--version`
Komenda zwracająca wersję aplikacji.

### 3. `--diagnostics`
Tryb techniczny:
- stack trace,
- provider info,
- loaded profile,
- SQL edition.

### 4. Publish single-file / self-contained jako oficjalne artefakty
Gotowe katalogi:
- `publish`
- `publish-win-x64`
- `publish-singlefile`

### 5. Lepszy README
Z:
- scenariuszami użycia,
- troubleshootingiem,
- przykładami eksportów,
- przykładowymi raportami.

### 6. Sample reports
Gotowe przykładowe pliki w repo:
- `sample-timeline.md`
- `sample-incident.json`

---

# Dalsze sprinty po 10

## Sprint 11 — specialized report writers
Dedykowane write’ry dla:
- nightly report
- incident report
- timeline report

## Sprint 12 — config-driven reports
Raporty sterowane konfiguracją:
- okna czasu,
- źródła,
- format,
- ścieżka outputu.

## Sprint 13 — integracje
Wysyłka do:
- maila,
- Teams,
- Slack,
- webhooka.

## Sprint 14 — scheduler / automation pack
Gotowe uruchamianie:
- Task Scheduler,
- PowerShell wrapper,
- dzienny raport,
- raport incydentu.

## Sprint 15 — reguły i alerting
Konfigurowalne reguły:
- jeśli failed jobs > 0
- jeśli critical errorlog entries > 0
- jeśli maintenance plan failed
- jeśli login failed > N

---

# Priorytety rozwoju po MVP

## Najwyższy priorytet
1. Lepsze report writers dla raportów operacyjnych
2. `--also-print`
3. `--verbose`
4. Rozszerzenie klasyfikacji ErrorLog
5. `jobs step-history`

## Średni priorytet
1. Konfiguracja reguł z JSON
2. Ranking najczęstszych problemów
3. Rozpoznawanie formatu po rozszerzeniu pliku
4. Timestamp w nazwach raportów

## Niższy priorytet
1. Integracje Teams / Slack / Mail
2. Zaawansowane grupowanie incydentów
3. Zaawansowane sample reports
4. Executive summary generowany automatycznie

---

# Podsumowanie

Opcjonalne rzeczy dzielą się praktycznie na 3 grupy:

## 1. Polishing CLI
- `--verbose`
- `--version`
- `--also-print`
- lepsze błędy

## 2. Lepsze raportowanie
- sekcyjne report writers
- ładniejszy Markdown
- timestampy i szablony

## 3. Rozwój operacyjny
- alerting
- config-driven reports
- integracje
- scheduler

