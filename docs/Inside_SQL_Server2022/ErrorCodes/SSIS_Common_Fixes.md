# SSIS – typowe błędy i naprawy

- **0xC0202009 / 0xC020801C – Acquire connection / conversion** → Drivery, CM, uprawnienia.  
- **0xC000F427 – ProtectionLevel** → `DontSaveSensitive`, parametry w SSISDB.  
- **DTS_E_PRODUCTLEVELTOLOW** → Zainstaluj SSIS/runtime.  
- **Excel (0xC0209303)** → Access Database Engine, dopasuj architekturę; w razie potrzeby `/32`.

**Diagnoza:** sprawdzaj `SSISDB.catalog.executions` i `catalog.operation_messages` (message_type 120 = error).