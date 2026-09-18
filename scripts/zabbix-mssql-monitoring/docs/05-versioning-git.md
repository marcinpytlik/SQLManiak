# Wersjonowanie szablonu Zabbix

Repozytorium Git jest źródłem prawdy dla szablonu:

`templates/SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly.yaml`

## Model pracy

```text
Zabbix LAB
   |
   | Export-ZabbixTemplate.ps1
   v
YAML w branchu Git
   |
   | git diff / review / PR
   v
master
   |
   | Compare-ZabbixTemplate.ps1
   | Import-ZabbixTemplate.ps1
   v
Zabbix docelowy
```

## Uwierzytelnianie

Skrypty korzystają z tokena API Zabbixa. Zalecane jest ustawienie go tylko w bieżącej sesji PowerShell:

```powershell
$env:ZABBIX_API_TOKEN = "<token>"
```

Nie zapisujemy tokena w repozytorium.

Adres API ma postać np. `https://zabbix.example.local/api_jsonrpc.php`.

## Eksport

```powershell
.\tools\Export-ZabbixTemplate.ps1 -ApiUrl "https://zabbix.example.local/api_jsonrpc.php"
```

Domyślnie eksportowany jest `SQLManiak MSSQL by Zabbix agent 2`.
Po eksporcie zawsze sprawdź:

```powershell
git diff -- scripts/zabbix-mssql-monitoring/templates
```

## Porównanie przed importem

```powershell
.\tools\Compare-ZabbixTemplate.ps1 -ApiUrl "https://zabbix.example.local/api_jsonrpc.php"
```

Skrypt korzysta z `configuration.importcompare` i pokazuje różnice bez wykonywania importu.

## Import

```powershell
.\tools\Import-ZabbixTemplate.ps1 -ApiUrl "https://zabbix.example.local/api_jsonrpc.php"
```

Bez parametru `-Force` skrypt wymaga ręcznego wpisania `IMPORT`.

### DeleteMissing

Domyślnie `DeleteMissing` jest wyłączone. Pełną synchronizację można wykonać świadomie przez `-DeleteMissing` po wcześniejszym compare.

## Zasady wersjonowania

- `master` jest źródłem prawdy.
- zmiany z GUI Zabbixa są robocze do momentu eksportu i merge do `master`,
- każda istotna zmiana szablonu powinna mieć wpis w `CHANGELOG.md`,
- wersje stabilne oznaczamy tagami Git, np. `zabbix-mssql-v1.6.0`,
- zmiany progów alertów wykonujemy oddzielnie od zmian strukturalnych, żeby diff był czytelny.
