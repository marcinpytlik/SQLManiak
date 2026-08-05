# SQL Server — Bazy danych

# 13. Checklisty

## 13.1. Codzienna kontrola baz

### Cel

Szybkie wykrycie problemów wpływających na dostępność, możliwość odtworzenia lub poprawne działanie baz danych.

### Checklista

- [ ] Wszystkie bazy produkcyjne mają stan `ONLINE`.
- [ ] Żadna baza nie znajduje się w stanie `SUSPECT`, `RECOVERY_PENDING` ani `EMERGENCY`.
- [ ] Wszystkie wymagane backupy `FULL`, `DIFF` i `LOG` zakończyły się poprawnie.
- [ ] Nie występują przerwy w łańcuchu backupów logu.
- [ ] Wolne miejsce w plikach i na wolumenach przekracza ustalone progi.
- [ ] Pliki logu nie są bliskie zapełnienia.
- [ ] Nie występuje nietypowy wzrost plików danych lub logu.
- [ ] Nie pojawiły się nowe wpisy w `[msdb].[dbo].[suspect_pages]`.
- [ ] Repliki AG są zsynchronizowane zgodnie z wymaganym trybem.
- [ ] Kolejka wysyłania logu i kolejka redo mieszczą się w progach.
- [ ] Nie występują błędy Log Shipping.
- [ ] Nie występują błędy kolektora centralnego.
- [ ] Nie występują nowe błędy 823, 824 lub 825.
- [ ] Nie występują niekontrolowane zmiany recovery model.

### Wynik

```text
Data:
Osoba wykonująca:
Status: OK / WARNING / CRITICAL
Liczba baz sprawdzonych:
Liczba problemów:
Najważniejsze obserwacje:
Działania:
Numer zgłoszenia:
```

---

## 13.2. Cotygodniowy przegląd baz

- [ ] Przejrzano historię i czasy trwania backupów z ostatnich 7 dni.
- [ ] Sprawdzono wzrost rozmiaru baz oraz plików danych i logu.
- [ ] Sprawdzono liczbę operacji autogrowth.
- [ ] Sprawdzono fragmentację indeksów i aktualność statystyk.
- [ ] Sprawdzono status ostatniego `DBCC CHECKDB`.
- [ ] Sprawdzono bazy bez aktualnego CHECKDB.
- [ ] Sprawdzono najdłuższe transakcje i `log_reuse_wait_desc`.
- [ ] Sprawdzono stan oraz rozmiar Query Store.
- [ ] Sprawdzono błędy HA/DR.
- [ ] Sprawdzono zmiany konfiguracji baz.
- [ ] Sprawdzono nowe i usunięte bazy.
- [ ] Sprawdzono bazy bez właściciela technicznego lub dokumentacji.
- [ ] Sprawdzono otwarte findingi i wyjątki.

---

## 13.3. Miesięczny audyt konfiguracji

- [ ] Recovery model jest zgodny ze standardem.
- [ ] Compatibility level jest zgodny z polityką i wymaganiami aplikacji.
- [ ] `AUTO_CLOSE = OFF`.
- [ ] `AUTO_SHRINK = OFF`.
- [ ] `PAGE_VERIFY = CHECKSUM`.
- [ ] Automatyczne tworzenie i aktualizacja statystyk są skonfigurowane poprawnie.
- [ ] `TRUSTWORTHY = OFF`, chyba że istnieje zatwierdzony wyjątek.
- [ ] Query Store jest skonfigurowany zgodnie ze standardem.
- [ ] RCSI, Snapshot Isolation i ADR są zgodne z wymaganiami aplikacji.
- [ ] Pliki mają poprawne nazwy i lokalizacje.
- [ ] Autogrowth jest określony w MB, nie w procentach.
- [ ] Każda baza ma właściciela technicznego.
- [ ] Każda baza produkcyjna ma właściciela biznesowego.
- [ ] Każda baza ma określoną krytyczność, RPO i RTO.
- [ ] Każda baza ma aktualną dokumentację.
- [ ] Backupy i TDE są zgodne z polityką bezpieczeństwa.
- [ ] Nie występują osieroceni użytkownicy.
- [ ] CHECKDB oraz test restore są wykonywane zgodnie z harmonogramem.
- [ ] Bazy HA/DR mają potwierdzony stan ochrony.
- [ ] Nie występują niewyjaśnione zmiany konfiguracji.

---

## 13.4. Checklista nowej bazy

### Przed utworzeniem

- [ ] Istnieje zatwierdzone zgłoszenie.
- [ ] Określono nazwę, środowisko i przeznaczenie bazy.
- [ ] Określono właściciela technicznego i biznesowego.
- [ ] Określono krytyczność, RPO i RTO.
- [ ] Określono rozmiar początkowy i przewidywany wzrost.
- [ ] Określono recovery model, HA/DR i wymagania szyfrowania.
- [ ] Określono retencję danych i compatibility level.

### Podczas tworzenia

- [ ] Nazwa bazy i plików jest zgodna ze standardem.
- [ ] Pliki znajdują się na właściwych wolumenach.
- [ ] Rozmiary początkowe i autogrowth są ustawione poprawnie.
- [ ] Recovery model i compatibility level są poprawne.
- [ ] `PAGE_VERIFY = CHECKSUM`.
- [ ] `AUTO_CLOSE = OFF` i `AUTO_SHRINK = OFF`.
- [ ] Query Store jest skonfigurowany.
- [ ] Utworzono wymagane role i nadano minimalne uprawnienia.

### Po utworzeniu

- [ ] Wykonano i zweryfikowano pierwszy backup FULL.
- [ ] Bazę dodano do monitoringu, backupów, CHECKDB i maintenance.
- [ ] Bazę dodano do HA/DR, jeżeli jest wymagane.
- [ ] Utworzono dokumentację.
- [ ] Test połączenia aplikacji zakończył się poprawnie.

---

## 13.5. Checklista migracji bazy

### Przygotowanie

- [ ] Określono źródło, cel i okno migracji.
- [ ] Sprawdzono wersję, edycję oraz compatibility level.
- [ ] Sprawdzono rozmiar bazy, czas backupu i restore.
- [ ] Sprawdzono wolne miejsce na celu.
- [ ] Sprawdzono loginy, joby, linked servers, SSIS, SSRS i Power BI.
- [ ] Sprawdzono certyfikaty, TDE, CDC, Change Tracking i temporal tables.
- [ ] Przygotowano plan rollback i testy akceptacyjne.

### Migracja

- [ ] Wykonano i zweryfikowano backup końcowy.
- [ ] Odtworzono bazę i loginy.
- [ ] Naprawiono użytkowników osieroconych.
- [ ] Zweryfikowano ownera, compatibility level i Query Store.
- [ ] Zweryfikowano joby, połączenia aplikacji, backupy i CHECKDB.
- [ ] Zweryfikowano HA/DR.

### Po migracji

- [ ] Wykonano testy aplikacyjne i wydajnościowe.
- [ ] Wykonano backup po migracji.
- [ ] Zaktualizowano monitoring, dokumentację i CMDB.
- [ ] Potwierdzono zakończenie rollback window.

---

## 13.6. Checklista po restore

- [ ] Restore zakończył się bez błędów.
- [ ] Baza ma oczekiwany stan.
- [ ] Wykonano `DBCC CHECKDB`.
- [ ] Zweryfikowano ownera i użytkowników osieroconych.
- [ ] Zweryfikowano recovery model, compatibility level i lokalizację plików.
- [ ] Zweryfikowano autogrowth, Query Store, Service Broker i TRUSTWORTHY.
- [ ] Zweryfikowano CDC, Change Tracking, TDE i certyfikaty.
- [ ] Zweryfikowano joby zależne, backupy i monitoring.
- [ ] Wykonano test aplikacyjny.

---

## 13.7. Checklista po failover

- [ ] Potwierdzono właściwą replikę PRIMARY.
- [ ] Wszystkie wymagane bazy są dostępne.
- [ ] Stan synchronizacji i kolejki AG są akceptowalne.
- [ ] Listener oraz połączenia aplikacyjne działają.
- [ ] Backup preference jest respektowane.
- [ ] Joby działają tylko na właściwej replice.
- [ ] Loginy, linked servers i Database Mail działają.
- [ ] Monitoring pokazuje właściwą rolę.
- [ ] Nie występują błędy SQL Server ani Windows Event Log.
- [ ] Zarejestrowano czas failover, RTO i ewentualną utratę danych.

---

## 13.8. Checklista przed usunięciem bazy

- [ ] Istnieje zatwierdzone zgłoszenie.
- [ ] Właściciele zaakceptowali usunięcie.
- [ ] Potwierdzono brak aktywnych połączeń i zależności.
- [ ] Sprawdzono joby, SSIS, SSRS, Power BI, linked servers, replikację i HA/DR.
- [ ] Wykonano i zweryfikowano końcowy backup FULL.
- [ ] Ustalono retencję backupu.
- [ ] Usunięto bazę z monitoringu, maintenance, backupów i jobów.
- [ ] Zaktualizowano dokumentację i CMDB.

---

## 13.9. Checklista testu DR

- [ ] Określono zakres i scenariusz awarii.
- [ ] Potwierdzono dostępność backupów, kluczy i certyfikatów.
- [ ] Potwierdzono dostępność infrastruktury DR.
- [ ] Odtworzono bazę lub wykonano failover.
- [ ] Zweryfikowano integralność, loginy, użytkowników i aplikację.
- [ ] Zweryfikowano joby, backupy oraz monitoring.
- [ ] Zmierzono RTO i zweryfikowano RPO.
- [ ] Udokumentowano problemy i plan działań naprawczych.
- [ ] Potwierdzono powrót do stanu normalnego.

---

## 13.10. Checklista zmiany compatibility level

### Przed zmianą

- [ ] Sprawdzono bieżący i docelowy compatibility level.
- [ ] Włączono Query Store i zebrano baseline.
- [ ] Wykonano testy funkcjonalne oraz wydajnościowe.
- [ ] Sprawdzono funkcje zależne od compatibility level.
- [ ] Przygotowano plan rollback.

### Po zmianie

- [ ] Potwierdzono dostępność bazy i poprawność aplikacji.
- [ ] Sprawdzono Query Store oraz regresje planów.
- [ ] Sprawdzono CPU, waity, blokady i błędy aplikacyjne.
- [ ] Wymuszono plany wyłącznie po analizie.
- [ ] Zaktualizowano dokumentację.

# 16. Standardy

## 16.1. Standard nazw baz

Zalecany format:

```text
<System>_<Moduł>[_<Środowisko>]
```

Przykłady:

```text
CRM_Core
CRM_Reporting
Finance_DWH_PROD
HelpDesk_Archive
```

Niedozwolone są spacje, polskie znaki, przypadkowe nazwy typu `Test1` oraz nazwy zawierające nazwiska osób.

---

## 16.2. Standard właścicieli baz

- Każda baza musi mieć właściciela technicznego.
- Każda baza produkcyjna musi mieć właściciela biznesowego.
- Właścicielem SQL nie powinno być konto osobiste.
- Zmiana właściciela wymaga zgłoszenia i wpisu w rejestrze zmian.

Minimalny zestaw danych:

```text
TechnicalOwner
BusinessOwner
Criticality
SupportGroup
ApplicationName
```

---

## 16.3. Standard plików danych

```text
<NazwaBazy>_Data.mdf
<NazwaBazy>_Data01.ndf
<NazwaBazy>_Data02.ndf
```

- Pliki danych znajdują się na dedykowanych wolumenach.
- Rozmiar początkowy odpowiada przewidywanemu użyciu.
- Dodatkowe pliki i filegroupy wymagają uzasadnienia.
- Rozmieszczenie plików musi być udokumentowane.

---

## 16.4. Standard plików logu

```text
<NazwaBazy>_Log.ldf
```

- Preferowany jest jeden plik logu.
- Log znajduje się na dedykowanym wolumenie.
- Plik jest pre-size’owany.
- Autogrowth jest ustawiony w MB.
- Cykliczny shrink logu jest zabroniony.
- Monitorowany jest `log_reuse_wait_desc`.

---

## 16.5. Standard filegroup

- Każda baza posiada filegroup `PRIMARY`.
- Dodatkowe filegroupy tworzy się tylko z uzasadnieniem.
- Duże tabele i dane archiwalne mogą mieć osobne filegroupy.
- Filegroup read-only wymaga procedury utrzymania.
- Każda filegroupa musi mieć opisane przeznaczenie.

---

## 16.6. Standard autogrowth

- Autogrowth w MB, nigdy w procentach.
- Wartość zależy od wielkości i charakteru bazy.
- Wzrost nie może następować zbyt często.
- Dane i log mają osobne wartości.

Przykładowe wartości początkowe:

```text
Mała baza:    Data 256 MB,  Log 128 MB
Średnia baza: Data 1024 MB, Log 512 MB
Duża baza:    Data 4096 MB, Log 1024 MB
```

---

## 16.7. Standard recovery model

### FULL

Dla baz wymagających odtwarzania do punktu w czasie, niskiego RPO, AG lub Log Shipping.

### SIMPLE

Dla baz tymczasowych, odtwarzanych z innego źródła albo z zaakceptowanym RPO.

- Zmiana recovery model wymaga zgłoszenia.
- Po przejściu do FULL wykonuje się pełny backup.
- Baza w FULL musi mieć regularny backup logu.
- Cykliczne przełączanie FULL/SIMPLE jest zabronione bez uzasadnienia.

---

## 16.8. Standard compatibility level

- Poziom zgodności musi być wspierany przez aplikację.
- Po migracji nie podnosi się go automatycznie.
- Przed zmianą zbiera się baseline Query Store.
- Zmiana wymaga testów funkcjonalnych i wydajnościowych.
- Regresje analizuje się, a nie maskuje restartem.

---

## 16.9. Standard Query Store

- Query Store powinien być włączony dla baz produkcyjnych.
- Rozmiar i retencja odpowiadają aktywności bazy.
- Monitorowany jest stan `READ_WRITE` / `READ_ONLY`.
- Wymuszone plany są okresowo przeglądane.
- Query Store nie jest czyszczony bez analizy.

---

## 16.10. Standard backupów

```text
FULL — co najmniej raz na dobę
DIFF — według RPO i wielkości bazy
LOG  — według RPO
```

- Backup jest monitorowany, kompresowany i przechowywany poza wolumenem danych.
- Szyfrowanie stosuje się zgodnie z polityką.
- Backup jest potwierdzony dopiero po teście restore.
- Copy-only stosuje się poza normalnym łańcuchem backupów.

---

## 16.11. Standard CHECKDB

- Każda baza produkcyjna ma regularny `DBCC CHECKDB`.
- Wynik jest zapisywany i monitorowany.
- Błędy integralności mają priorytet krytyczny.
- `PHYSICAL_ONLY` nie zastępuje pełnego CHECKDB.
- Dla VLDB można stosować udokumentowaną strategię rozdzieloną.

---

## 16.12. Standard bezpieczeństwa

- Obowiązuje zasada najmniejszych uprawnień.
- Konta aplikacyjne nie są członkami `db_owner` bez zatwierdzonego wyjątku.
- Preferowane są role bazodanowe zamiast pojedynczych grantów.
- Użytkownicy osieroceni są niedozwoleni.
- `TRUSTWORTHY` domyślnie jest wyłączone.
- TDE, szyfrowanie backupów i klasyfikacja danych są zgodne z polityką.
- Klucze i certyfikaty muszą być backupowane.

---

## 16.13. Standard monitoringu

Każda baza produkcyjna musi być monitorowana co najmniej pod kątem:

- statusu,
- backupów,
- CHECKDB,
- rozmiaru i wzrostu,
- wolnego miejsca,
- użycia logu,
- błędów 823, 824 i 825,
- HA/DR,
- Query Store,
- blokad, deadlocków i długich transakcji.

Każdy alert ma określone:

```text
Severity
Owner
Runbook
EscalationPath
NotificationChannel
```

---

## 16.14. Standard dokumentacji

Każda baza produkcyjna posiada:

- nazwę aplikacji i opis przeznaczenia,
- właściciela technicznego i biznesowego,
- krytyczność, RPO i RTO,
- recovery model i compatibility level,
- wymagania backupowe i HA/DR,
- zależności,
- procedurę odtworzenia,
- datę ostatniego przeglądu.

Statusy:

```text
MISSING
GENERATED
IN_REVIEW
APPROVED
OUTDATED
RETIRED
```

---

## 16.15. Minimalny standard bazy PROD

- [ ] Baza jest `ONLINE`.
- [ ] Ma właściciela technicznego i biznesowego.
- [ ] Ma określoną krytyczność, RPO i RTO.
- [ ] Ma poprawny recovery model i compatibility level.
- [ ] Ma `PAGE_VERIFY = CHECKSUM`.
- [ ] Ma `AUTO_CLOSE = OFF` i `AUTO_SHRINK = OFF`.
- [ ] Ma poprawny autogrowth.
- [ ] Ma aktualny backup FULL i wymagane backupy LOG.
- [ ] Ma aktualny CHECKDB.
- [ ] Jest objęta monitoringiem.
- [ ] Ma aktualną dokumentację.
- [ ] Ma potwierdzony test restore.
- [ ] Ma wymaganą ochronę HA/DR.
- [ ] Nie ma otwartych findingów CRITICAL bez planu działania.

---

## 16.16. Kody naruszeń standardów

| Kod | Opis | Ważność |
|---|---|---|
| `DB_STATE_NOT_ONLINE` | Baza nie jest ONLINE | CRITICAL |
| `DB_OWNER_MISSING` | Brak właściciela technicznego | HIGH |
| `DB_BUSINESS_OWNER_MISSING` | Brak właściciela biznesowego | MEDIUM |
| `DB_RECOVERY_MODEL_INVALID` | Nieprawidłowy recovery model | HIGH |
| `DB_LOG_BACKUP_MISSING` | Brak backupu logu | CRITICAL |
| `DB_FULL_BACKUP_MISSING` | Brak aktualnego backupu FULL | CRITICAL |
| `DB_CHECKDB_MISSING` | Brak aktualnego CHECKDB | HIGH |
| `DB_PAGE_VERIFY_INVALID` | PAGE_VERIFY inne niż CHECKSUM | HIGH |
| `DB_AUTO_CLOSE_ENABLED` | AUTO_CLOSE włączone | MEDIUM |
| `DB_AUTO_SHRINK_ENABLED` | AUTO_SHRINK włączone | HIGH |
| `DB_TRUSTWORTHY_ENABLED` | TRUSTWORTHY włączone bez wyjątku | HIGH |
| `DB_AUTOGROWTH_PERCENT` | Autogrowth ustawiony procentowo | MEDIUM |
| `DB_AUTOGROWTH_TOO_SMALL` | Autogrowth zbyt mały | MEDIUM |
| `DB_QUERY_STORE_DISABLED` | Query Store wyłączony | MEDIUM |
| `DB_QUERY_STORE_READ_ONLY` | Query Store w stanie READ_ONLY | MEDIUM |
| `DB_COMPATIBILITY_OUTDATED` | Nieaktualny compatibility level | MEDIUM |
| `DB_DOCUMENTATION_MISSING` | Brak dokumentacji | MEDIUM |
| `DB_RESTORE_TEST_MISSING` | Brak testu restore | HIGH |
| `DB_HA_REQUIRED_MISSING` | Brak wymaganej ochrony HA | CRITICAL |
| `DB_DR_REQUIRED_MISSING` | Brak wymaganej ochrony DR | CRITICAL |
| `DB_ORPHANED_USERS` | Użytkownicy osieroceni | HIGH |
| `DB_TDE_REQUIRED_MISSING` | Brak wymaganego TDE | HIGH |
| `DB_DISK_SPACE_LOW` | Niski poziom wolnego miejsca | CRITICAL |
| `DB_LOG_SPACE_HIGH` | Wysokie użycie logu | HIGH |
| `DB_UNCONTROLLED_GROWTH` | Niekontrolowany wzrost bazy | HIGH |
