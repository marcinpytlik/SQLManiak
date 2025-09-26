# Katalog błędów: Linked Server + SSIS

- **LinkedServer_Errors.csv** – mapa Msg → znaczenie → fix (OLE DB/ODBC, RPC OUT, MSDTC, ANSI options).  
- **SSIS_Errors.csv** – mapa kodów SSIS → przyczyny → fix.  
- Snippety T-SQL do tworzenia/diagnozy Linked Serverów oraz uruchamiania pakietów z SSISDB, uprawnienia i 32‑bit runtime.

## Szybkie wskazówki
- DML przez Linked Server → pamiętaj o **MSDTC** i Kerberos (double hop).  
- Dziwne błędy providera (65535/80004005) → sprawdź **Event Viewer** i architekturę driverów.  
- SSIS z Excel/ACE → często wymaga **32-bit** i odpowiedniego pakietu **Access Database Engine**.