# Podnoszenie Compatibility Level do 160 (SQL Server 2022)

## Założenie
Po migracji A/B → C/D zostawiasz bazy na **130 (SQL 2016)**, stabilizujesz, a następnie podnosisz do **160** z asekuracją Query Store.

## Kroki (na każdej bazie)
1. **Post-restore higiena** – `sql_common/20_prep_after_restore.sql`  
   CHECKDB, pełne statystyki, Query Store = ON/RW, `FORCE_LAST_GOOD_PLAN=ON`.
2. **Flip do 160** – `sql_common/21_upgrade_to_160.sql`  
   `ALTER DATABASE ... SET COMPATIBILITY_LEVEL = 160` + `CLEAR PROCEDURE_CACHE`.
3. **Awaryjnie** – `sql_common/22_emergency_switches.sql`  
   `LEGACY_CARDINALITY_ESTIMATION=ON` albo `PARAMETER_SENSITIVE_PLAN_OPTIMIZATION=OFF`.
4. **Hurtowo** – `sql_common/23_bulk_upgrade_template.sql`.

## Kolejność
1. **D (Subscriber)** → 2. **C (Publisher)** → 3. (opcjonalnie) **distribution**.

## PowerShell „bez myślenia”
```powershell
Set-Location .\scripts
Copy-Item .\Params.sample.psd1 .\Params.psd1
# Podnieś na subskrybencie (D)
.0.Compat-Prep-And-Upgrade.ps1 -ParamsPath .\Params.psd1 -ServerRole D -Databases 'TwojaBaza'
# Podnieś na publisherze (C)
.0.Compat-Prep-And-Upgrade.ps1 -ParamsPath .\Params.psd1 -ServerRole C -Databases 'TwojaBaza'
```

## Uwaga
Replikacja nie wymaga identycznego poziomu zgodności po obu stronach; zmieniasz w dogodnym momencie. Monitoruj Query Store pod kątem regresji planów.
