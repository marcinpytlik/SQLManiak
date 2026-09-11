# SQL Server CDC POC

Laboratoryjny Proof of Concept dla SQL Server Change Data Capture.

## Kolejność uruchamiania

1. `00_CreateDatabase.sql` – tworzy bazę `CDC_Lab`.
2. `01_CreateTables.sql` – tworzy tabele `Customer` i `CustomerOrder`.
3. `02_EnableCDC.sql` – włącza CDC dla bazy i obu tabel.
4. `03_GenerateData.sql` – generuje operacje INSERT / UPDATE / DELETE.
5. `04_ReadChanges.sql` – pokazuje fizyczne tabele CDC oraz `all changes` i `net changes`.
6. `05_CDC_Monitoring.sql` – pokazuje konfigurację, joby, sesje skanowania, błędy, latencję i rozmiar change tables.
7. `06_CDC_Retention.sql` – pokazuje i zmienia retencję oraz parametry joba capture.
8. `99_Cleanup.sql` – wyłącza CDC i usuwa bazę testową.

## Cel POC

POC pokazuje:

- jak SQL Server CDC wykorzystuje transaction log,
- jak wygląda capture instance i tabela `cdc.*_CT`,
- znaczenie `__$operation`, `__$start_lsn` i `__$seqval`,
- różnicę pomiędzy `fn_cdc_get_all_changes_*` i `fn_cdc_get_net_changes_*`,
- mapowanie LSN na czas,
- działanie jobów capture i cleanup,
- podstawowy monitoring i diagnostykę CDC,
- wpływ retencji na dostępność zakresu LSN.

## Następny etap

Docelowy etap integracyjny POC:

`SQL Server -> CDC -> Debezium -> Kafka -> Consumer`

W tym etapie warto przetestować restart connectora, backlog, DELETE, UPDATE before/after, zmiany schematu oraz sytuację, gdy cleanup CDC usunie LSN wymagany jeszcze przez konsumenta.
