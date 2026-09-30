# Troubleshooting

Ta część SQLManiak DBA Library jest organizowana według **problemu lub symptomu**, a nie według lokalizacji skryptu.

Celem jest przejście od pytania:

> Gdzie jest skrypt?

do pytania:

> Co powinienem sprawdzić przy tym problemie?

## Obszary

- [Blocking](blocking/)
- [Deadlocks](deadlocks/)
- [CPU](cpu/)
- [Wait Statistics](wait-statistics/)
- [Query Store](query-store/)
- [Query Performance](query-performance/)
- [Memory](memory/)
- [I/O](io/)
- [TempDB](tempdb/)
- [Replication](replication/)
- [Backup / Restore](backup-restore/)
- [SQL Agent](sql-agent/)
- [HA / DR](ha-dr/)

Kolejne obszary będą dokładane iteracyjnie.

## Model pracy

Każdy obszar troubleshooting powinien prowadzić przez ten sam schemat:

1. **Symptoms** – co widzi użytkownik lub monitoring.
2. **First checks** – co sprawdzić jako pierwsze.
3. **Evidence** – jakie dane zebrać.
4. **Hypotheses** – jakie przyczyny rozważyć.
5. **Diagnosis** – jak potwierdzić root cause.
6. **Resolution** – jak naprawić problem.
7. **Validation** – jak potwierdzić poprawę.
8. **Prevention** – jak ograniczyć ryzyko powtórzenia.

## Ważna zasada

Ten katalog nie duplikuje istniejących skryptów i dokumentacji.

Jeżeli dobry artefakt już istnieje w `scripts/`, `tools/` albo `docs/`, troubleshooting **linkuje do źródła prawdy**.

Do tworzenia nowych materiałów używaj [TROUBLESHOOTING-TEMPLATE.md](../templates/TROUBLESHOOTING-TEMPLATE.md).


---

## Nawigacja między warstwami

- [DBA Library Cross-Link Map](../docs/DBA-LIBRARY-MAP.md)
- [Content Lifecycle](../docs/CONTENT-LIFECYCLE.md)
- [Legacy / Reference Cleanup](../docs/LEGACY-CLEANUP.md)
