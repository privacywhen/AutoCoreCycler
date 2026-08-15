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

**Resolve:** Inspect the current apply/readback path and reuse the smallest adequate mechanism.

**Close when:** Phase 4 has a verified, tested application gate.

## I002 — Multi-workload transition feasibility

**Class:** `LATER`  
**Phase:** 3

It is not yet proven that CoreCycler can transition through the required Kagari/Prime95 stages in-process without stale configuration/process state or invasive resets.

**Resolve:** Perform the Phase 3 feasibility checkpoint; use the smallest coordinator form preserving the evidence contract.

**Close when:** the coordinator form is selected from code evidence and its stage boundaries are testable.

## I003 — Unattributed WHEA conflicts with discovery semantics

**Class:** `LATER`  
**Phase:** 4

PR #182 has a path that can treat APIC-unavailable WHEA as an error for the tested core. Discovery requires unattributable or mismatched WHEA to remain ambiguous.

**Resolve:** Gate discovery so unattributable WHEA cannot establish a boundary while preserving legacy ATM behaviour.

**Close when:** discovery attribution tests pass and affected legacy behaviour remains unchanged.

## I004 — Resume policy mismatch

**Class:** `LATER`  
**Phase:** 2 / 4

Existing PR #182 recovery assumes the previously active core may have crashed and adjusts toward stability. Discovery must distinguish infrastructure interruption from unexplained disruptive interruption without manufacturing an attributed boundary.

**Resolve:** Reuse the recovery substrate with discovery-specific retry/quarantine classification.

**Close when:** synthetic resume tests cover both interruption classes without false boundaries or unsafe reapplication.

## I005 — Minimum evidence fingerprint

**Class:** `LATER`  
**Phase:** 2 / 3

The minimum context needed to reject stale or incompatible discovery evidence is not finalized.

**Resolve:** Include only fields needed to detect materially incompatible evidence, likely CPU/platform state, workload/config identity, and relevant software version. Do not build a generalized environment inventory.

**Close when:** stale/incompatible evidence is rejected by a documented, tested fingerprint.

## I006 — Phase 1 test environment

**Class:** NOT_A_PROBLEM
**Phase:** 1

**Resolution:** Windows PowerShell 5.1.22621.6060 and Pester 3.4.0 are installed. Pester 3 supports the repository-local focused command used by Phase 1: Invoke-Pester -Script @{ Path = 'tests\DiscoveryState.Tests.ps1' } -PassThru. No dependency-management machinery was added.

**Closed when:** The focused command ran successfully in the development repo with 6 passed and 0 failed tests.
## I007 — Existing coverage of shared upstream paths

**Class:** `LATER`  
**Phase:** 2–5

The regression coverage for the specific PR #182/CoreCycler paths discovery will modify has not yet been mapped.

**Resolve:** At the start of each integration phase, identify only the shared paths actually being changed and determine whether adequate legacy coverage already exists. Add focused characterization where it does not.

**Close when:** every shared path modified by discovery has adequate baseline coverage and its relevant regression checks are included in the phase gate.

## I008 — Discovery starting-value compatibility

**Class:** `LATER`
**Phase:** 4

Current ATM initialization expands one scalar `startValues` entry to all cores only when it matches the negative-integer form `^\s*\-\d+\s*$`. On a multi-core CPU, scalar `startValues = 0` therefore does not use the all-core expansion path, even though scalar negative starts do.

**Resolve:** Before discovery CO integration, determine the smallest compatibility path for a neutral discovery start without changing legacy ATM semantics. Prefer discovery-local initialization or an independently characterized, backward-compatible shared fix only if it is genuinely required.

**Close when:** Phase 4 proves multi-core neutral discovery start configuration is accepted and mapped correctly, or records a deliberate documented constraint with an approved alternative.

## Current focus

**Planned next phase:** Phase 1 — pure discovery semantics.

When Phase 1 is authorized, only `I006` is currently in scope. Other issues remain deferred unless new evidence makes one a blocker.
