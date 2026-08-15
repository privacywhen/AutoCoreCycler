# PLAN.md

# AutoCoreCycler Descending Discovery Plan

Implementation sequence for `GOAL.md` and `DESIGN.md`. This file does **not** authorize work by itself. Implement only the explicitly authorized phase; do not solve later phases early unless required to avoid a demonstrated dead end.

**Next:** Phase 1  
**Hardware:** not authorized by this plan

When a phase changes shared upstream behaviour, apply the focused characterization rule in `AGENTS.md` and include the affected legacy behaviour in that phase's gate.

## Phase 1 — Pure discovery semantics

**Objective:** Prove the state machine without changing production execution.

**Deliver:**
- focused Pester tests;
- minimal pure transition/validation helpers;
- coverage for full/partial suite outcomes, attributable/ambiguous/infrastructure results, platform limit, no valid baseline, verified-application gating, terminal filtering, and candidate/stage identity separation.

**Gate:**
- focused tests pass;
- PowerShell parses cleanly;
- no launch, CO, workload, resume, or hardware path is wired to the helpers;
- diff is limited to Phase 1.

## Phase 2 — Durable state and recovery

**Objective:** Persist Phase 1 semantics through PR #182 state/results machinery without changing workload execution.

**Deliver:**
- discovery state/resolution persistence and required schema handling;
- candidate/stage identity validation;
- resolved-core filtering;
- synthetic stale, torn, interrupted, and recovered-state tests.

**Gate:**
- invalid/stale state cannot advance a core;
- terminal attempts are not repeated;
- infrastructure interruption can retry without moving the CPU boundary;
- affected legacy state/resume behaviour remains intact;
- stress/CO execution paths remain unchanged.

## Phase 3 — Multi-workload gate

**Objective:** Produce one candidate result from the complete required suite while reusing CoreCycler execution/parsing.

**Feasibility checkpoint:** inspect the actual workload/config/process lifecycle before choosing coordinator form. Prefer a small in-process coordinator if clean; otherwise use the smallest hybrid orchestration preserving the evidence contract. Do not duplicate parsers, affinity, or CO control.

**Deliver:**
- stable candidate identity across the suite;
- fresh stage identity/evidence boundary per workload;
- verified current-stage progression and stale-output rejection;
- one `OBSERVED_PASS` only after the full suite;
- fail-fast attributable failure and no advancement from ambiguous/infrastructure outcomes.

**Gate:**
- synthetic suite progression and stale-evidence tests pass;
- affected legacy workload/parser behaviour remains intact;
- discovery additions remain localized to the smallest practical seam.

## Phase 4 — Scheduler and CO integration

**Objective:** Connect discovery semantics to ATM scheduling and existing tested-core-only CO application while preserving legacy ATM.

**Deliver:**
- opt-in discovery mode;
- synchronous rung scheduling and isolated candidate application;
- verified effective-map gate;
- exact `N → N-1` advancement after a complete pass;
- correct resolution, retry, and quarantine behaviour;
- legacy `Test-AutomaticTestModeIncrease` semantics unchanged.

**Gate:**
- mocked/synthetic end-to-end rung tests pass;
- affected legacy scheduler/WHEA/CO behaviour remains intact;
- no real stress workload or CO write is required to prove the software path;
- diff review finds no unnecessary semantic divergence.

## Phase 5 — Non-hardware acceptance

**Objective:** Prove the complete control path and upstream compatibility boundary before hardware testing.

Exercise synthetic end-to-end scenarios for multiple cores/rungs, all evidence classes, retry/quarantine, platform/no-baseline resolution, restart/resume, stale/torn recovery, and legacy ATM compatibility.

Record the **actual upstream integration assumptions** discovery now depends on, such as relevant state/resume contracts, WHEA attribution, workload lifecycle, and CO application behaviour. Keep this list limited to real dependencies.

**Gate:**
- project-prescribed static/parser/tests pass;
- `git diff --check` and `git status` show only intended changes;
- focused legacy regression/characterization tests pass;
- documented integration assumptions match current code;
- independent review finds no material correctness, legacy-regression, or unnecessary-divergence issue.

Hardware testing may be proposed only after this gate.

## Phase 6 — Supervised hardware trial

**Requires separate explicit authorization.**

Use the smallest trial that validates the real control path before a full optimization run.

Verify one initial UAC elevation, actual isolated candidate readback, correct attempt/stage identity, expected durable transition from a valid result, and safe cleanup/recovery.

Expand hardware scope only after this trial succeeds.

## Later milestone — Combined-map validation

Define combined-map validation only after isolated discovery is trustworthy in real hardware use. Do not let it delay or complicate discovery.

## Upstream update requalification

After a meaningful upstream merge, inspect which documented integration assumptions or shared seams changed and rerun only the relevant characterization/feature tests plus normal project verification. A clean merge alone is not evidence of semantic compatibility.

## Completion rule

A phase is complete only when its gate has fresh evidence. Report files changed, verification/results, blockers or limitations, deferred findings, and whether the diff stayed within scope.
