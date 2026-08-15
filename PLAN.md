# PLAN.md

# AutoCoreCycler Descending Discovery Plan

Implementation sequence for `GOAL.md` and `DESIGN.md`. This file does **not** authorize work by itself. Implement only the explicitly authorized phase; do not solve later phases early unless required to avoid a demonstrated dead end.

**Next:** Phase 3 — real terminal-result and runtime bridge
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

## Phase 3 — Real terminal-result and runtime bridge

**Objective:** Produce a stage result from actual CoreCycler parser/lifecycle terminal behavior, carry it safely through a fresh child boundary, and reduce it through the existing ordered-suite interface without hardware execution.

**Feasibility checkpoint:** **complete — use a minimal hybrid coordinator.** Each workload stage runs as a fresh CoreCycler child invocation; the coordinator retains discovery state and consumes only an explicitly stage-scoped terminal result. In-process switching is rejected because CoreCycler selects startup-global configuration/adapter state, rewrites program-global configuration, and retains parser/process state. Do not duplicate parsers, affinity, WHEA collection, or CO control.

**Current foundation:** discovery state/persistence, config-byte fingerprints, stage context/result identity validation, pure ordered suite reduction, deterministic child plans/readiness, observed PID/UTC context binding, and an isolated child launch adapter exist. They are not yet the runtime bridge: no actual CoreCycler parser/lifecycle terminal point currently emits a discovery result, and no parent currently supplies the verified exit/cleanup evidence needed before suite input can count.

**Deliver:**
- characterize the existing CoreCycler parser/lifecycle completion and classified error terminal points before fixing protocol fields;
- one opt-in production-compatible terminal observation, classification, and atomic result-emission seam at those actual points;
- controlled non-hardware coverage through that same seam for `PASS`, `ATTRIBUTED_FAIL`, `AMBIGUOUS_FAIL`, and `INFRASTRUCTURE_INVALID`;
- strict outcome classification: attributable calculation errors or APIC-mapped active-core WHEA may establish `ATTRIBUTED_FAIL`; unattributed WHEA remains ambiguous; `PROCESSMISSING`, `CPULOAD`, and execution/lifecycle/parser/config/log/protocol failures remain infrastructure-invalid absent concrete attributable silicon evidence;
- exact candidate/stage/config/log/PID/UTC-start identity and stale/duplicate/malformed result rejection;
- bounded ownership cleanup when a child starts but cannot be reliably bound, with no suite input unless cleanup can be verified;
- characterization of the real authoritative finite stress-process cleanup identity source before committing it to a protocol;
- real harmless CoreCycler child transport through the same result machinery, proving ownership, identity, artifact transport, exit, and cleanup while producing only `INFRASTRUCTURE_INVALID`.

**Gate:**
- the production terminal seam covers known parser/lifecycle completion and classified error paths without changing legacy ATM when discovery is inactive;
- controlled observations through that same production seam prove all four evidence classes, with `ATTRIBUTED_FAIL` limited to positive trustworthy active-core attribution;
- a real harmless child proves transport, ownership, bound PID/UTC identity, exit, and cleanup through the same result reader/emitter but never emits `PASS` or claims hardware stability;
- stale, malformed, duplicate, timeout, unbound-child, or cleanup-uncertain data cannot reach suite reduction;
- the existing suite reducer accepts only matching results with actual Boolean child-exit and cleanup evidence;
- focused affected-legacy workload/parser behavior remains intact and the change stays localized.

**Stop rule:** Stop Phase 3 once this gate has fresh evidence. Do not add multi-core scheduling or a separate harness-only result architecture.

## Phase 4 — One-core candidate integration

**Objective:** Prove the complete software-control path for one core and one candidate through controlled apply/readback and the canonical ordered discovery suite while preserving legacy ATM.

**Characterization checkpoint:** Before modifying a shared ATM, CO, or application path, capture focused baseline behavior only for the contracts actually touched: tested-core isolation-map construction, candidate application, effective-map readback/normalization, and any relevant legacy pass/error/resume behavior. Characterize scalar `startValues` initialization only if it blocks this one-core path. Do not build a broad CoreCycler test suite for unrelated behavior.

**Deliver:**
- opt-in discovery candidate selection separate from legacy uphill ATM policy;
- controlled application through the smallest adequate existing CO mechanism plus exact normalized effective-map readback;
- `APPLIED_VERIFIED` only after the intended map is confirmed, never from intended values alone;
- one canonical required workload-set definition used by both production discovery and acceptance tests:
  1. y-cruncher Kagari;
  2. Prime95 SSE Huge FFT;
  3. Prime95 AVX2 720K / 768K;
  4. Prime95 AVX2 1344K;
- a controlled successful software-control path for one core/one candidate:
  `candidate selection → controlled apply + exact readback → APPLIED_VERIFIED → all four ordered stages through the production terminal/result interfaces → complete-suite OBSERVED_PASS → exact N → N-1 → durable persistence and restoration`;
- a controlled attributable-failure path through the same composed interfaces:
  `ATTRIBUTED_FAIL → previous-pass DISCOVERY_CANDIDATE or NO_VALID_BASELINE → durable persistence → no automatic reapplication of the failed/suspect candidate`;
- focused proof that ambiguous disruption continues to quarantine rather than reapply;
- legacy `Test-AutomaticTestModeIncrease`, `confirmed`, error/reset, and resume stabilization semantics unchanged.

Controlled terminal observations and apply/readback adapters in this phase prove software control and state handling only. They are not hardware stability evidence, and no real workload or CO operation is required for this gate.

**Gate:**
- the successful and attributable-failure one-core composed paths pass using the production terminal/result interfaces and the canonical four-stage workload set;
- a successful path persists and restores exactly one `N → N-1` transition only after complete-suite `OBSERVED_PASS`;
- an attributable-failure path persists the correct previous-pass boundary or `NO_VALID_BASELINE` and produces no automatic reapply request;
- absent/mismatched effective-map readback blocks `APPLIED_VERIFIED` and all stage launch;
- focused baseline characterization covers every shared legacy contract actually touched;
- no discovery path changes legacy ATM directional/status semantics or conflates discovery with `confirmed`/`knownGoodValues`;
- no real stress workload or CO write is required to prove the software path;
- diff review finds no unnecessary semantic divergence.

**Stop rule:** Do not generalize scheduler behavior until this one-core gate has fresh evidence and independent review.

## Phase 5 — Synchronous multi-core rung progression and non-hardware acceptance

**Objective:** Generalize only the proven one-core mechanism into the v1 synchronous rung barrier, then verify the broader software path and upstream compatibility boundary before hardware testing.

**Deliver:**
- synchronous rung progression across unresolved cores using the established one-core candidate/apply/suite/persistence mechanism;
- multi-core neutral discovery start compatibility or a documented approved constraint before that path is enabled;
- synthetic end-to-end scenarios for multiple cores/rungs, all evidence classes, retry/quarantine, platform/no-baseline resolution, restart/resume, stale/torn recovery, and legacy ATM compatibility;
- a limited record of the actual upstream integration assumptions discovery depends on, including state/resume, WHEA attribution, workload lifecycle, cleanup identity, and CO application/readback behavior.

**Gate:**
- all generalized behavior reuses the proven one-core semantics without weaker evidence or identity gates;
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
