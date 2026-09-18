# Źródłowy arkusz wymagań

Źródłem macierzy wymagań dla projektu jest plik:

```text
MSSQL_alerty_Grafana_macierz_v6_complete_CPU_SQL.xlsx
```

Na jego podstawie powstało mapowanie wymagań do szablonu Zabbix opisane w:

- [`../docs/02-excel-mapping.md`](../docs/02-excel-mapping.md),
- katalogu [`../docs/excel-mapping/`](../docs/excel-mapping/).

## Identyfikacja pliku

Oryginalny arkusz używany przy przygotowaniu dokumentacji ma sumę SHA256:

```text
559ed06a2720d7c66844d5c23e97d3f7d0c6aab105358c657848ece05f6b7e04
```

Dzięki temu po skopiowaniu arkusza do repozytorium można jednoznacznie potwierdzić, że jest to ta sama wersja, na której oparto mapowanie.

## Docelowa lokalizacja

```text
scripts/zabbix-mssql-monitoring/source/MSSQL_alerty_Grafana_macierz_v6_complete_CPU_SQL.xlsx
```

> Uwaga techniczna: używany w tej sesji konektor GitHub nie obsługuje poprawnego zapisu tego binarnego pliku XLSX jako pojedynczego obiektu. Próba bezpośredniego zapisu została wykryta jako niepełna i wycofana, aby nie pozostawić w repozytorium uszkodzonego arkusza. Dokumentacja i suma SHA256 wskazują dokładnie właściwy plik źródłowy.
