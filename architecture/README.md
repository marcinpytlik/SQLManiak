# Architecture

Warstwa Architecture opisuje **dlaczego środowisko jest zbudowane w określony sposób** oraz jakie trade-offy stoją za decyzjami technicznymi.

---

# Architecture Decision Records

- [ADR-001 — Layered DBA Library Operating Model](adr/ADR-001-dba-library-operating-model.md)
- [ADR-002 — Local TempDB on SQL Server FCI Nodes](adr/ADR-002-local-tempdb-in-fci.md)
- [ADR-003 — Side-by-Side Migration from SQL Server 2016 to 2022](adr/ADR-003-side-by-side-sql2016-to-2022.md)
- [ADR-004 — Query Store Baseline Before Compatibility-Level Change](adr/ADR-004-query-store-baseline-before-compat-change.md)
- [ADR-005 — Baseline-First Monitoring Instead of Universal Static Thresholds](adr/ADR-005-baseline-first-monitoring.md)

Nowe decyzje dokumentuj przy użyciu:

- [ADR Template](../templates/ADR-TEMPLATE.md)

---

# Reference Architectures

- [SQL Server FCI](reference/fci-reference-architecture.md)
- [SQL Server Monitoring](reference/monitoring-reference-architecture.md)
- [SQL Server 2016 → 2022 Migration](reference/migration-reference-architecture.md)

---

# Existing architecture decisions

Nie przenosimy istniejących zaakceptowanych ADR-ów tylko po to, żeby zmienić katalog.

Przykład istniejącego source of truth:

- [Secure export without Unconstrained Delegation](../scripts/ssis-secure-export-poc/ADR-001-secure-export-without-unconstrained-delegation.md)

Kluczowa decyzja tego ADR:

```text
application identity != execution identity
```

czyli request jest składany przez aplikację, a downstream execution wykonywany przez dedykowaną tożsamość techniczną przez SQL Agent Proxy.

---

# Architecture vs Standards vs Runbooks

```text
Architecture / ADR
= dlaczego wybraliśmy ten model

Standard
= jakiego stanu oczekujemy

Monitoring
= czy stan jest utrzymany

Troubleshooting
= dlaczego wystąpił problem

Runbook
= jak bezpiecznie wykonać operację
```

---

# ADR rules

ADR powinien zawierać:

- Context,
- Decision drivers,
- Considered options,
- Decision,
- Consequences,
- Validation,
- Revisit when,
- References.

ADR nie jest runbookiem i nie powinien kopiować procedur krok po kroku.

Statusy:

```text
Proposed
Accepted
Superseded
Deprecated
```

Jeżeli decyzja zostaje zastąpiona, stary ADR pozostaje w repo z odwołaniem do nowego.


---

## Nawigacja między warstwami

- [DBA Library Cross-Link Map](../docs/DBA-LIBRARY-MAP.md)
- [Content Lifecycle](../docs/CONTENT-LIFECYCLE.md)
- [Legacy / Reference Cleanup](../docs/LEGACY-CLEANUP.md)
