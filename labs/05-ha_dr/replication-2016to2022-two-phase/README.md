# Migracja dwuetapowa: SQL 2016 (A/B) → SQL 2022 (C/D)

Patrz foldery: `sql_phase1_subscriber`, `sql_phase2_pubdist`, `scripts`, `checklist`, `docs`.


## Monitoring „plug & play”
Po Faza 2 (C=2022 jako Publisher+Distributor) możesz od razu włączyć monitoring:

```powershell
Set-Location .\scripts
Copy-Item .\Params.sample.psd1 .\Params.psd1
# edytuj adres e-mail w sql_common\10_alerts_and_operator.sql (Operator ReplOps)
.\30.Setup-Alerts.ps1 -ParamsPath .\Params.psd1
.\31.Setup-Healthcheck.ps1 -ParamsPath .\Params.psd1 -EveryMinutes 10
.\40.Dashboard.ps1 -ParamsPath .\Params.psd1
```

- `sql_common/10_alerts_and_operator.sql` — Operator + alerty 14151/14157 + podpięcie do jobów Agentów.
- `sql_common/11_latency_healthcheck.sql` — logger latency do `msdb.dbo.ReplLatencyLog`.
- `sql_common/12_dashboard_dmv.sql` — szybki status replikacji i log.


## Podnoszenie Compatibility Level (do 160)
- SQL: `sql_common/20_prep_after_restore.sql`, `21_upgrade_to_160.sql`, `22_emergency_switches.sql`, `23_bulk_upgrade_template.sql`
- PS:  `scripts/60.Compat-Prep-And-Upgrade.ps1` (C/D, lista baz)

Szybki start:
```powershell
Set-Location .\scripts
Copy-Item .\Params.sample.psd1 .\Params.psd1
.\60.Compat-Prep-And-Upgrade.ps1 -ParamsPath .\Params.psd1 -ServerRole D -Databases 'TwojaBaza'
.\60.Compat-Prep-And-Upgrade.ps1 -ParamsPath .\Params.psd1 -ServerRole C -Databases 'TwojaBaza'
```
Dokumentacja: `docs/CompatLevel.md`
