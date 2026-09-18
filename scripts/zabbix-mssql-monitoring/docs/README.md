# Dokumentacja SQLManiak — monitoring MSSQL w Zabbix 7.4

Ten katalog zawiera dokumentację użytkową szablonu `SQLManiak MSSQL by Zabbix agent 2` w wersji **v1.6**.

Dokumentacja jest utrzymywana po polsku. Nazwy techniczne, takie jak nazwy itemów Zabbixa, klucze, makra, nazwy DMV, liczniki SQL Server i nazwy plików, pozostają w oryginalnej postaci, jeśli są identyfikatorami używanymi bezpośrednio przez szablon lub skrypty.

## Zalecana kolejność czytania

1. [Przegląd i pełny inwentarz szablonu](01-template-inventory.md)
2. [Mapowanie wymagań z Excela na implementację](02-excel-mapping.md)
3. [Instrukcja instalacji i konfiguracji](03-installation.md)
4. [Słownik pojęć i skrótów](04-slownik.md)
5. [Wersjonowanie szablonu w Git](05-versioning-git.md)
6. Szczegółowy [inwentarz itemów, prototypów, triggerów i makr](inventory/)
7. Szczegółowe [mapowanie pozycji z arkusza Excel](excel-mapping/)

## Materiał źródłowy

Informacje o źródłowym arkuszu wymagań, jego nazwie i sumie SHA256 znajdują się w:

[`../source/README.md`](../source/README.md)

## Zakres dokumentacji

Dokumentacja opisuje:

- architekturę monitoringu,
- wymagania po stronie Zabbix Server/Proxy,
- konfigurację Zabbix Agent 2 i dodatku MSSQL,
- własne zapytania SQLManiak,
- wymagane uprawnienia SQL Server,
- mechanizm E2E,
- monitoring CPU i schedulerów,
- monitoring I/O,
- blokady i deadlocki,
- aktywne i długie transakcje,
- monitoring baz danych, filegroupów i VLF,
- TDE,
- SLA backupów i jobów SQL Server Agent,
- linię bazową i wykrywanie anomalii,
- mapowanie między pierwotną macierzą Excel a aktualnym szablonem Zabbixa,
- wersjonowanie szablonu Zabbix w Git oraz bezpieczny eksport, compare i import przez API,
- słownik najważniejszych skrótów i pojęć użytych w dokumentacji.

## Jak czytać inwentarz

W tabelach inwentarza występują cztery podstawowe kolumny:

| Kolumna | Znaczenie |
|---|---|
| **Nazwa** | rzeczywista nazwa itemu, prototypu lub triggera w szablonie |
| **Klucz** | klucz Zabbixa lub wyrażenie używane przez dany element |
| **Sposób zbierania** | mechanizm pozyskania danych: Agent 2, własne zapytanie, item zależny, item obliczany, prosty test lub test zewnętrzny |
| **Co mierzy / znaczenie** | polski opis funkcji i interpretacji metryki |

## Konwencje językowe

W dokumentacji używam polskich odpowiedników tam, gdzie poprawiają czytelność, np.:

- *template* → **szablon**,
- *custom query* → **własne zapytanie**,
- *dependent item* → **item zależny**,
- *calculated item* → **item obliczany**,
- *discovery rule* → **reguła wykrywania**,
- *item prototype* → **prototyp itemu**,
- *trigger prototype* → **prototyp triggera**,
- *baseline* → **linia bazowa**,
- *anomaly* → **anomalia**,
- *capacity* → **pojemność**,
- *response time* → **czas odpowiedzi**.

Nie tłumaczyłem identyfikatorów technicznych zapisanych w kodzie, np. `mssql.e2e.response_ms`, `VIEW SERVER STATE`, `sys.dm_db_log_info()` czy `Memory Grants Pending`.

Jeżeli pojawia się skrót, którego znaczenie nie jest oczywiste, sprawdź [słownik](04-slownik.md). Zawiera m.in. E2E, MAD, LLD, AG, WSFC, FCI, TDE, VLF, PLE, DMV, SLA, TTL i inne pojęcia używane w szablonie.

## Wersja szablonu

Aktualnie opisana wersja:

```text
v1.6-baseline-anomaly
```

Historia zmian znajduje się w [`../CHANGELOG.md`](../CHANGELOG.md).
