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

**Class:** `NOT_A_PROBLEM`
**Phase:** 3

**Resolution:** The Phase 3 lifecycle checkpoint found that CoreCycler selects startup-global settings/adapters, writes program-global configuration, and retains parser/process state. A minimal hybrid coordinator that uses one fresh CoreCycler child per workload stage is the smallest safe form; no in-process adapter-switch seam is required or selected.

**Closed when:** Code inspection independently established the coordinator form and its stage boundaries: non-mutating stage config delivery, stage-scoped terminal evidence, and verified child/process cleanup.

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

**Class:** `MUST_FIX_CURRENT_PHASE`
**Phase:** 3

The pure foundation now provides an explicit non-mutating child config input, validates stage identity against candidate/stage IDs, config bytes, log identity, PID, and start time, and reduces synthetic stage results through ordered-suite progression. It requires explicit child-exit/process-cleanup evidence, accepts only the final ordered pass as `OBSERVED_PASS`, and fails fast or stops progression for attributable, ambiguous, and infrastructure outcomes. A deterministic child-launch plan validates a non-root stage config, captures its config-byte fingerprint, validates a fresh log target, retains the identity template, and produces the explicit PowerShell argument array without starting a process. A pure just-before-launch readiness check repeats the child-script, config-byte, and log-freshness checks so a mutated plan input cannot cross the later executor boundary. A separate pure observation adapter accepts a caller-supplied positive PID and explicit UTC start time, binds them through the existing stage-context contract, and rejects post-plan config drift without requiring the log to remain absent after launch. It is not wired to actual child launch/runtime parsing, so no real child result can count.

**Resolve:** Wire the established config/evidence/coordinator contracts through the minimal child coordinator; preserve the same candidate/stage/config/log/PID/start-time binding, and reject missing, mismatched, stale, or post-cleanup-ambiguous evidence. Do not build a generalized environment inventory.

**Close when:** synthetic stage progression and stale/incompatible evidence tests prove the coordinator accepts only matching stage evidence **and** a dedicated child-launch seam supplies those contracts from fresh CoreCycler children without invoking a workload in verification.

## I006 — Phase 1 test environment

**Class:** NOT_A_PROBLEM
**Phase:** 1

**Resolution:** Windows PowerShell 5.1.22621.6060 and Pester 3.4.0 are installed. Pester 3 supports the repository-local focused command used by Phase 1: Invoke-Pester -Script @{ Path = 'tests\DiscoveryState.Tests.ps1' } -PassThru. No dependency-management machinery was added.

**Closed when:** The focused Phase 1 command ran successfully in the development repo using the installed Windows PowerShell 5.1 and Pester 3.4 environment.
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

**Phase 2:** durable-state and recovery foundation is complete; its current integrity checks are limited to synthetic persistence/recovery contracts.
**Phase 3:** lifecycle feasibility checkpoint complete; hybrid coordinator selected. The pure child-config, stage-evidence, and synthetic ordered-suite coordinator contracts are implemented and tested; actual child launch/runtime parsing and full CoreCycler suite progression are not started.

`I005` remains the current Phase 3 must-fix: wire stage-scoped configuration and evidence identity through the coordinator before any child result can count. All other issues remain deferred unless new evidence makes one a blocker.
