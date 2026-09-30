# ADR-001: Layered DBA Library Operating Model

- Status: Accepted
- Date: 2026-09-30
- Owners: SQLManiak / DBA

## Context

Repozytorium zawiera dużą liczbę skryptów, laboratoriów, checklist, dokumentów i narzędzi. Problemem nie jest brak wiedzy, lecz znalezienie właściwego artefaktu i odróżnienie polityki od diagnostyki oraz procedury wykonawczej.

## Decision drivers

- jeden source of truth,
- brak duplikowania skryptów,
- szybka nawigacja podczas incydentu,
- możliwość iteracyjnej migracji istniejących treści,
- czytelne rozdzielenie polityki od operacji.

## Considered options

### Option A — jeden duży katalog dokumentacji

Odrzucono jako trudny do skalowania i podatny na mieszanie standardów, diagnostyki i procedur.

### Option B — pełna reorganizacja repo od razu

Odrzucono ze względu na ryzyko zerwania istniejących ścieżek i linków.

### Option C — warstwowy model + Strangler

Przyjęto.

## Decision

DBA Library używa czterech głównych warstw:

```text
Standards
   ↓
Monitoring
   ↓
Troubleshooting
   ↓
Runbooks
```

Znaczenie:

- **Standards** — jak powinno być,
- **Monitoring** — czy nadal tak jest,
- **Troubleshooting** — dlaczego jest źle,
- **Runbooks** — jak bezpiecznie wykonać operację/recovery.

Istniejące `docs/`, `scripts/`, `tools/`, `labs/` pozostają source of truth dla konkretnych artefaktów, dopóki nie są świadomie migrowane.

## Consequences

### Positive

- łatwiejsza nawigacja,
- brak big-bang reorganization,
- istniejące narzędzia pozostają użyteczne,
- nowe treści mają wspólny model.

### Negative / Trade-offs

- przez pewien czas repo ma równolegle „stare” i „nowe” ścieżki,
- wymaga konsekwentnego cross-linkingu,
- nie wszystkie stare artefakty są od razu sklasyfikowane.

## Validation

- każdy nowy obszar ma link do istniejącego source of truth,
- brak kopiowania dużych skryptów między warstwami,
- użytkownik może przejść Standard → Monitoring → Troubleshooting → Runbook.

## Revisit when

- większość legacy content zostanie już sklasyfikowana,
- obecny top-level przestanie skalować się na nowe domeny.

## References

- [Repository README](../../readme.md)
- [Standards](../../standards/)
- [Monitoring](../../monitoring/)
- [Troubleshooting](../../troubleshooting/)
- [Runbooks](../../runbooks/)
