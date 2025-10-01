# Lab 02 — TempDB Contention (PAGELATCH na PFS/SGAM/IAM)

Celem labu jest **wywołanie i zdiagnozowanie contention w tempdb** oraz pokazanie **mitigacji**:
- odpowiednia liczba plików danych tempdb (zwykle: min(CPU, 8))
- równe rozmiary i autogrowth **=**
- wyłączenie mixed page allocation (domyślnie OFF od SQL 2016)
- monitorowanie WAIT-ów: `PAGELATCH_UP/EX` na PFS/SGAM/.. stronach w **tempdb**

> Środowisko: SQL Server 2019/2022 (Developer), **nie produkcja**.

## Plan
1. **Setup**: raport bieżącej konfiguracji tempdb i WAIT-ów.
2. **Reprodukcja**: skrypt otwierający wiele #temp i alokujący w pętli, odpalany w kilku równoległych sesjach.
3. **Diagnoza**: DMV dla waitów, latchy i stron alokacyjnych.
4. **Mitigacja**: dodanie plików tempdb (jeśli potrzebne), wyrównanie rozmiarów, AUTOGROW_ALL_FILES, restart usługi.
5. **Weryfikacja**: ponowny test i porównanie metryk.

## Uwaga
- Stare trace flagi 1117/1118 są **zbędne** w SQL Server 2016+ (zachowanie zaimplementowane domyślnie).
- Do silnej reprodukcji użyj kilku równoległych sesji (np. 4–8 zapytań w SSMS/VS Code, SQLQueryStress lub `Start-Job` w PowerShell).


## Weryfikacja
- Po dodaniu plików i restarcie powtórz `02_repro_contention.sql` w 4–8 sesjach.
- Porównaj łączny `wait_time_ms` dla `PAGELATCH_XX` przed/po.
- Sprawdź, czy pliki mają **identyczny rozmiar** i **ten sam autogrowth**.

## Sprzątanie
Zmiany w tempdb zostają – jeśli to lab, przywróć oryginalną konfigurację ręcznie.
