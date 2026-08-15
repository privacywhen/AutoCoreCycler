# DECISIONS.md

# AutoCoreCycler Durable Decisions

Record only settled choices not already requirements in `GOAL.md` or operating rules in `AGENTS.md`. Architecture detail belongs in `DESIGN.md`; sequencing belongs in `PLAN.md`.

Reopen a decision only when new evidence shows a material conflict with the goal, correctness, upstream compatibility, or a simpler durable design.

## D001 — Use PR #182/CoreCycler infrastructure as the substrate

**Decision:** Reuse PR #182/CoreCycler execution, affinity, CO-map, parsing, persistence, and recovery machinery where adequate. Descending discovery is a separate policy; do not repurpose legacy uphill ATM policy transitions as a bidirectional optimizer.

**Rationale:** Reuses operational machinery while avoiding false equivalence between legacy confirmation/stabilization semantics and discovery evidence/boundaries. This minimizes duplicate mechanics, regression risk, semantic divergence, and future upstream merge burden.

**Reopen if:** no localized policy seam can satisfy discovery without making shared infrastructure materially more fragile, or a smaller shared abstraction demonstrably preserves both policies more clearly.

## D002 — Isolate the candidate to the tested core

**Decision:** Phase 1 applies the candidate only to the active core; non-tested cores stay at an explicitly controlled safe value.

Preferred mechanism:

```ini
setVoltageOnlyForTestedCore = 1
applyConfirmedValuesForNotTestedCores = 0
```

**Rationale:** Improves attribution and reduces unrelated-core instability.

**Reopen if:** implementation or hardware evidence shows isolation materially misrepresents the boundary or creates a larger correctness problem.

## D003 — Use a synchronous rung scheduler for v1

**Decision:** Test every unresolved core at the current rung before survivors advance. Each individual test remains isolated.

**Rationale:** Simple, auditable progression without uneven per-core advancement to reconcile.

**Reopen if:** another scheduler is demonstrably simpler or more reliable while preserving the discovery contract.

## D004 — Separate candidate identity from stage identity

**Decision:** One candidate-attempt ID spans a core/CO value across the full suite; each workload execution has its own stage-attempt ID and evidence boundary.

**Rationale:** Prevents stale/resumed output from satisfying another candidate or stage.

**Reopen if:** existing CoreCycler evidence identity provides the same invariant with less machinery.

## D005 — Keep discovery state distinct from `confirmed`

**Decision:** Do not encode isolated discovery completion as PR #182 `confirmed` or `knownGoodValues`.

**Rationale:** Those terms imply stronger confirmed/not-retested semantics than discovery proves.

**Reopen if:** upstream semantics change so existing fields can represent discovery without ambiguity or compatibility risk.

## D006 — Quarantine unexplained disruptive candidates

**Decision:** If a verified candidate is associated with an unexplained disruptive interruption without sufficient attribution, do not establish a boundary or automatically reapply it. Controlled/infrastructure interruptions remain retryable.

**Rationale:** Avoids false boundaries and repeated exposure to a potentially disruptive candidate.

**Reopen if:** reliable attribution/recovery evidence supports a safer automatic path.

## D007 — Add discovery-specific policy without reversing legacy ATM

**Decision:** Preserve legacy uphill ATM semantics and implement descending discovery through separate policy/state transitions. Small shared refactors are acceptable when they create a cleaner extension seam without changing legacy behaviour.

**Rationale:** Minimizes regression risk and upstream divergence without forcing brittle wrappers.

**Reopen if:** a smaller shared abstraction provides equally clear semantics and compatibility.
