Plan migracji (A/B = SQL 2016 → C/D = SQL 2022)

Poniżej szczegółowy, wykonywalny plan z mapą: skrypt, gdzie uruchomić i w jakiej kolejności.
Odnosi się do nowego repo dwuetapowego: replication-2016to2022-two-phase.

Oznaczenia i założenia

A (2016) – stary Publisher + Distributor

B (2016) – stary Subscriber

C (2022) – nowy Publisher + (docelowo) Distributor

D (2022) – nowy Subscriber (docelowo zastąpi B)

DB – TwojaBaza (podmień w skryptach)

Publication – PubName (podmień)

Ścieżki backupów i snapshotów w skryptach są przykładowe – dostosowac przed startem.

FAZA 1 — Migracja subskrybenta (B → D)

Cel: D(2022) staje się subskrybentem (najlepiej PULL), A(2016) nadal Publisher+Distributor.
Dlaczego tak: Publisher 2016 → Subscriber 2022 jest wspierane; przygotowuje grunt pod fazę 2.

1) Inwentaryzacja (opcja, ale warto)

A → (tylko podgląd, brak zmian)
sql_phase1_subscriber/00_inventory_A.sql

2) Zezwól na inicjalizację z backupu (na publikacji)

A
sql_phase1_subscriber/01_enable_init_from_backup_on_publication_A.sql

3) Backupy wyjściowe z A

A
sql_phase1_subscriber/02_backups_on_A.sql
(Tworzy TwojaBaza_p1_full.bak i TwojaBaza_p1_log.trn w \\A\Backups)

4) Restore na D (2022)

D
sql_phase1_subscriber/03_restore_on_D.sql
(Odtwarza FULL+LOG)

5) Utworzenie PULL subscription na D (zalecane)

D
sql_phase1_subscriber/04_create_pull_subscription_on_D.sql

Ustaw prawidłowe: @publisher = 'ServerA', @working_directory, tryby logowania.

Jeśli musisz mieć PUSH (niezalecane tu): utwórz subskrypcję push na A do D. Wtedy w Fazie 2 trzeba będzie odtworzyć Distribution Agent na C – patrz niżej (krok F2.6 – wariant PUSH).

6) Walidacja przepływu

A lub D
sql_phase1_subscriber/05_validate_phase1.sql
(Token tracer, historia; oczekujesz „Arrived”, mały latency)

7) Przełączenie ruchu z B na D

Aplikacje/raporty kieruj teraz do D. B zamrażasz/odstawiasz.

FAZA 2 — Publisher + Distributor (A → C) w jednym oknie

Cel: C(2022) = Publisher + Distributor, D(2022) = Subscriber.
Ważne: nie możesz zostawić dystrybutora na 2016, kiedy Publisher będzie 2022.

F2.1) Quiesce + finalny log na A

A
sql_phase2_pubdist/10_quiesce_and_final_log_A.sql
(Stop LogReader/Distribution – jeśli jeszcze działają, FINAL LOG backup → TwojaBaza_p2_FINAL_LOG.trn)

F2.2) Restore na C z KEEP_REPLICATION

C
sql_phase2_pubdist/11_restore_on_C_keep_replication.sql
(FULL → LOG → FINAL_LOG WITH KEEP_REPLICATION, RECOVERY, potem sp_vupgrade_replication)

F2.3) Konfiguracja dystrybucji na C (lokalny dystrybutor)

C
sql_phase2_pubdist/12_configure_distribution_on_C.sql
( sp_adddistributor → sp_adddistributiondb → sp_adddistpublisher → sp_addpublication_snapshot )

Zmień hasła, ścieżki (@working_directory), itp.

F2.4) D jest PULL? Zrób redirect A→C na D

D
sql_phase2_pubdist/13_redirect_on_D_to_C.sql
( sp_redirect_publisher i sp_get_redirected_publisher → agent pull na D zaczyna czytać z C)

Wariant PUSH (jeśli w F1 zrobiono PUSH na D):
Zamiast F2.4, wykonaj na C:
sql_phase2_pubdist/14_create_push_agent_on_C.sql
(tworzy Distribution Agent na C do D; pamiętaj o loginach/SID-ach agentów)

F2.5) Walidacja po przeniesieniu

C
sql_phase2_pubdist/15_validate_phase2.sql
( sp_validate_redirected_publisher, tracer tokeny, historia, sp_replcounters )

F2.6) Sprzątanie na A (dopiero przy pełnej stabilizacji)

A
sql_phase2_pubdist/16_cleanup_on_A.sql
(drop dist. publisher/db/distributor – po upewnieniu się, że C działa stabilnie)

Monitoring „plug & play” (na C po Fazie 2)
M1) Operator + alerty 14151/14157 + powiadomienia do jobów

C
sql_common/10_alerts_and_operator.sql

Zmień e-mail operatora ReplOps i (opcjonalnie) wzorzec jobów.

M2) Healthcheck (tracer token logger do msdb)

C
sql_common/11_latency_healthcheck.sql

M3) Mini-dashboard DMV + ostatnie latency

C
sql_common/12_dashboard_dmv.sql

Wersje PowerShell (jeden strzał):

C
scripts/30.Setup-Alerts.ps1 -ParamsPath .\Params.psd1
scripts/31.Setup-Healthcheck.ps1 -ParamsPath .\Params.psd1 -EveryMinutes 10
scripts/40.Dashboard.ps1 -ParamsPath .\Params.psd1

Podnoszenie compatibility level do 160 (po stabilizacji)
CL1) Higiena po restore (jeszcze na 130)

C i D (osobno dla każdej bazy)
sql_common/20_prep_after_restore.sql
(CHECKDB, pełne STATs, Query Store ON/RW, FORCE_LAST_GOOD_PLAN=ON)

CL2) Flip do 160 

D → potem C → ewentualnie distribution
sql_common/21_upgrade_to_160.sql
( ALTER DATABASE … SET COMPATIBILITY_LEVEL=160 + CLEAR PROCEDURE_CACHE )

CL3) Bezpieczniki awaryjne (jeśli jakaś reguła zwariuje)

C/D (per baza, doraźnie)
sql_common/22_emergency_switches.sql

LEGACY_CARDINALITY_ESTIMATION = ON|OFF

PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = OFF|ON

CL4) Hurtowo (wiele baz)

C/D
sql_common/23_bulk_upgrade_template.sql

PowerShell (automatycznie, bez ręcznej edycji T-SQL):

D
scripts/60.Compat-Prep-And-Upgrade.ps1 -ParamsPath .\Params.psd1 -ServerRole D -Databases 'TwojaBaza'

C
scripts/60.Compat-Prep-And-Upgrade.ps1 -ParamsPath .\Params.psd1 -ServerRole C -Databases 'TwojaBaza'

Runbooki PowerShell (skróty)

Faza 1 – B→D (Subscriber)
scripts/Runbook-Phase1.ps1 -ParamsPath .\scripts\Params.psd1

Faza 2 – A→C (Publisher+Distributor)
scripts/Runbook-Phase2.ps1 -ParamsPath .\scripts\Params.psd1

Monitoring
scripts/30.Setup-Alerts.ps1 … → scripts/31.Setup-Healthcheck.ps1 … → scripts/40.Dashboard.ps1 …

Compat level 160
scripts/60.Compat-Prep-And-Upgrade.ps1 …

Notatki operacyjne i pułapki

W Fazie 2 dystrybutor na C musi być ≥ wydawca (2022) – dlatego konfigurujesz dystrybucję na C w tym samym oknie, co restore z KEEP_REPLICATION.

Preferuj PULL na D – w Fazie 2 wystarczy sp_redirect_publisher na D, bez odtwarzania Distribution Agentów.

Loginy agentów i SID-y – jeśli przechodzisz na PUSH, przenieś konta agentów na C z identycznymi SID (w starym repo masz gotowce 16_compare_login_sids.sql/17_generate_login_script_from_A.sql).

Snapshot dir – upewnij się, że @working_directory istnieje i ma prawa dla konta Snapshot/Distribution.

Rollback – dopóki nie uruchomisz agentów na C, masz łatwiejszą drogę odwrotu (zależnie od etapu).