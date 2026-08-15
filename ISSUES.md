# ISSUES.md

# AutoCoreCycler Open Issues

Track unresolved questions and known conflicts that could change implementation. Planned work already covered by `PLAN.md` does not belong here.

Classes:

- `BLOCKER` — prevents correct completion of the current phase.
- `MUST_FIX_CURRENT_PHASE` — must be resolved before the current phase gate.
- `LATER` — real issue, but not current-phase scope.
- `NOT_A_PROBLEM` — investigated and closed without a fix.

Only `BLOCKER` and `MUST_FIX_CURRENT_PHASE` may expand current-phase work.

## I001 — Effective CO map verification

**Class:** `LATER`  
**Phase:** 4

The design requires verified effective CO application before stability evidence counts, but the existing CoreCycler mechanism that can establish this claim has not been selected.

**Resolve:** Characterize the current apply/readback path and reuse the smallest adequate mechanism for the one-core vertical slice.

**Close when:** Phase 4 has a verified, tested application gate that blocks `APPLIED_VERIFIED` on absent or mismatched readback.

## I002 — Multi-workload transition feasibility

**Class:** `NOT_A_PROBLEM`
**Phase:** 3

**Resolution:** The Phase 3 lifecycle checkpoint found that CoreCycler selects startup-global settings/adapters, writes program-global configuration, and retains parser/process state. A minimal hybrid coordinator that uses one fresh CoreCycler child per workload stage is the smallest safe form; no in-process adapter-switch seam is required or selected.

**Closed when:** Code inspection independently established the coordinator form and its stage boundaries: non-mutating stage config delivery, stage-scoped terminal evidence, and verified child/process cleanup.

## I003 — Legacy WHEA/process classification conflicts with discovery evidence

**Class:** `MUST_FIX_CURRENT_PHASE`
**Phase:** 3

Existing CoreCycler error handling can treat APIC-unavailable WHEA or process/load errors as errors for the currently tested core. Discovery must not convert that behavior into a silicon boundary without positive active-core attribution.

**Resolve:** At the production terminal classification seam, accept `ATTRIBUTED_FAIL` only for direct attributable calculation failure, equivalent attributable `CALCULATIONERROR`, or WHEA whose usable APIC/core mapping positively identifies the active core. Keep unattributed WHEA as `AMBIGUOUS_FAIL`; keep `PROCESSMISSING`, `CPULOAD`, and execution/lifecycle/parser/config/log/protocol failures as `INFRASTRUCTURE_INVALID` unless concrete evidence independently establishes attributable silicon instability. Preserve legacy ATM classification/behavior outside discovery mode.

**Close when:** Controlled production-seam classification tests cover all four discovery outcomes and affected legacy behavior remains unchanged.

## I004 — Resume policy mismatch

**Class:** `LATER`  
**Phase:** 4–5

Existing PR #182 recovery assumes the previously active core may have crashed and adjusts toward stability. Discovery must distinguish infrastructure interruption from unexplained disruptive interruption without manufacturing an attributed boundary.

**Resolve:** Reuse the recovery substrate with discovery-specific retry/quarantine classification at the integration seam.

**Close when:** Composed discovery control tests cover both interruption classes without false boundaries or unsafe reapplication.

## I005 — Production terminal-result and lifecycle bridge

**Class:** `MUST_FIX_CURRENT_PHASE`
**Phase:** 3

The pure foundation validates discovery state, stage identity, config-byte fingerprint, log identity, PID, UTC start time, ordered suite progression, and strict Boolean lifecycle gates. The isolated child plan/readiness/observation/launch adapter can start a harmless synthetic child, but no actual CoreCycler parser/lifecycle terminal point yet emits a discovery result and no parent bridge yet establishes verified child exit and stress-process cleanup before suite input.

**Resolve:** Characterize the real CoreCycler completion and classified error points, add one opt-in production terminal observation/classification/atomic-emission seam there, and connect its identity-bound result through a parent lifecycle gate to the existing suite reducer. The harmless real CoreCycler child must exercise that exact result machinery only to prove ownership, PID/start-time binding, transport, exit, and cleanup; it must emit only `INFRASTRUCTURE_INVALID`, never `PASS`. Characterize the authoritative finite stress-process cleanup identity source before fixing protocol fields; do not use broad process-name discovery or a separate harness-only result architecture.

**Close when:** The Phase 3 gate in `PLAN.md` has fresh evidence: controlled production-seam fixtures cover `PASS`, `ATTRIBUTED_FAIL`, `AMBIGUOUS_FAIL`, and `INFRASTRUCTURE_INVALID`; harmless child transport is verified without stability PASS; and stale, malformed, timeout, unbound, or cleanup-uncertain data cannot reach suite reduction.

## I006 — Phase 1 test environment

**Class:** `NOT_A_PROBLEM`
**Phase:** 1

**Resolution:** Windows PowerShell 5.1.22621.6060 and Pester 3.4.0 are installed. Pester 3 supports the repository-local focused command used by Phase 1: Invoke-Pester -Script @{ Path = 'tests\DiscoveryState.Tests.ps1' } -PassThru. No dependency-management machinery was added.

**Closed when:** The focused Phase 1 command ran successfully in the development repo using the installed Windows PowerShell 5.1 and Pester 3.4 environment.

## I007 — Existing coverage of shared upstream paths

**Class:** `LATER`  
**Phase:** 3–5

The regression coverage for the specific PR #182/CoreCycler paths discovery will modify has not yet been mapped.

**Resolve:** At the start of each integration phase, identify only the shared paths actually being changed and determine whether adequate legacy coverage already exists. Add focused characterization where it does not.

**Close when:** Every shared path modified by discovery has adequate baseline coverage and its relevant regression checks are included in the phase gate.

## I008 — Discovery starting-value compatibility

**Class:** `LATER`
**Phase:** 5

Current ATM initialization expands one scalar `startValues` entry to all cores only when it matches the negative-integer form `^\s*\-\d+\s*$`. On a multi-core CPU, scalar `startValues = 0` therefore does not use the all-core expansion path, even though scalar negative starts do.

**Resolve:** Before multi-core discovery progression, determine the smallest compatibility path for a neutral discovery start without changing legacy ATM semantics. Prefer discovery-local initialization or an independently characterized, backward-compatible shared fix only if it is genuinely required.

**Close when:** Multi-core discovery proves neutral-start configuration is accepted and mapped correctly, or records a deliberate documented constraint with an approved alternative.

## Current focus

**Phase 2:** durable-state and recovery foundation is complete; its current integrity checks are synthetic persistence/recovery contracts.

**Phase 3:** the hybrid fresh-child form and pure state/evidence/suite/launch foundations are complete. The active remaining work is the real CoreCycler terminal-result and parent lifecycle bridge: characterize existing parser/lifecycle terminal points, classify and emit an identity-bound result through one production seam, establish child exit and cleanup evidence, and prove harmless transport cannot manufacture stability evidence.

`I003` and `I005` are current Phase 3 must-fix items. `I001`, `I004`, and `I008` remain deferred until the Phase 3 gate passes; no synchronous multi-core scheduler work is in scope before the one-core Phase 4 vertical slice is proven.
