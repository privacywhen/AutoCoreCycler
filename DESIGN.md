# DESIGN.md

# AutoCoreCycler Descending Discovery Design

Current technical design for `GOAL.md`. Implementation may change when evidence justifies it; the goal and settled decisions do not.

## Architecture and upstream boundary

Reuse PR #182/CoreCycler execution infrastructure where adequate; do not treat its legacy Automatic Test Mode (ATM) stabilization policy as a generic bidirectional optimizer.

```text
Shared CoreCycler / PR #182 infrastructure
  core selection / affinity
  CO-map construction and application
  stress-process control
  result / WHEA collection and parsing
  durable state / results / resume
  tested-core isolation-map machinery
          │
          ├── Legacy ATM stabilization policy (unchanged)
          │     PASS → collect same-value confirmations → `confirmed`
          │     error/failure → increase toward `maxValue` → reset confirmations
          │
          └── Opt-in descending discovery policy
                complete-suite verified PASS → candidate - 1
                attributable failure → resolve to previous observed pass
                ambiguous/infrastructure evidence → no silicon boundary
```

Reuse shared execution, parsing, affinity, CO-map, persistence, and recovery mechanisms only where their concrete contracts fit discovery. `Test-AutomaticTestModeIncrease`, legacy confirmation counters/statuses, `maxValue`, and legacy error/crash adjustment are uphill ATM policy, not discovery policy. Descending discovery is opt-in; ordinary CoreCycler and PR #182 uphill ATM semantics remain unchanged.

Do not invert, rename broadly, or neutralize directional legacy paths merely for a symmetrical interface. A small shared refactor is acceptable only when it creates a real extension seam while preserving legacy behavior.

Prefer, in order:

1. existing extension/configuration mechanisms;
2. localized discovery branches/adapters;
3. small shared refactors that create a clean policy seam;
4. broad upstream rewrites only when correctness requires them.

Avoid copied upstream logic, unrelated reformatting, or discovery state spread through unrelated paths. Shared upstream paths modified by discovery need focused legacy regression/characterization coverage.

After future upstream merges, requalify the actual integration seams discovery depends on, not merely whether Git merged cleanly.

## Discovery model

### Isolation

Test one physical core at a time with its candidate CO while non-tested cores remain at an explicitly controlled safe value.

Prefer:

```ini
setVoltageOnlyForTestedCore = 1
applyConfirmedValuesForNotTestedCores = 0
```

Persistent per-core candidates are not the applied CPU map; only the active core receives its discovery candidate.

Existing tested-core isolation-map construction is reusable infrastructure, not proof that the exact intended discovery safe map was applied. Characterize its concrete non-tested-core behavior before relying on it for discovery evidence.

### Rung scheduler

The v1 scheduler is a synchronous rung barrier:

```text
0:   all unresolved cores
-1:  surviving unresolved cores
-2:  surviving unresolved cores
...
```

A core must earn the current rung before advancing. Resolved or quarantined cores leave the active set.

This scheduler is deliberately deferred. First prove the complete one-core/one-candidate control path, including its successful and attributable-failure durable transitions. Do not introduce multi-core progression while that vertical slice lacks fresh evidence.

## Attempt and stage identity

A **candidate attempt** represents one core at one CO value across the complete required suite and binds:

- physical core;
- candidate CO;
- workload-set/config fingerprint;
- unique candidate-attempt ID.

Each workload execution has a separate **stage-attempt ID** plus a fresh evidence boundary. Old output must not satisfy a new candidate or stage.

```text
SCHEDULED
→ APPLYING
→ APPLIED_VERIFIED
→ RUNNING_SUITE
→ terminal evidence
```

`APPLIED_VERIFIED` is mandatory before workload evidence can count. Reuse the strongest adequate existing CoreCycler mechanism for application verification.

## Workload gate

A candidate earns one `OBSERVED_PASS` only after every required stage passes, in order, within the same candidate attempt.

The canonical discovery workload set is defined once for both production discovery and software-control acceptance:

1. y-cruncher Kagari: BKT, BBP, SFTv4, SNT, SVT, FFTv4, N63, VT3; 2 threads.
2. Prime95 SSE Huge FFT: 8960K–32768K; 1 thread.
3. Prime95 AVX2: 720K / 768K; 1 thread; 3 min/core.
4. Prime95 AVX2: 1344K; 1 thread; 3 min/core.

A valid attributable failure is fail-fast for that core/candidate.

Use a minimal hybrid coordinator: it retains candidate/stage state and runs each workload stage as a fresh CoreCycler child invocation. Do not live-switch CoreCycler workload adapters in one process. CoreCycler selects startup-global configuration/adapter state, rewrites program-global configuration, and retains parser/process state; an in-process switch would require invasive reset logic and create stale-evidence risk.

For each stage, the coordinator supplies non-mutating stage-specific configuration and binds accepted evidence to the candidate ID, stage ID, workload/config fingerprint, stage-unique log identity, child PID, and stage start time. It must verify child exit and expected stress-process cleanup before the next stage. Reuse the child’s existing launch, affinity, completion, WHEA, parser, and cleanup behavior rather than duplicating them.

## Terminal observation, result emission, and lifecycle evidence

Phase 3 extends actual CoreCycler terminal behavior; it does not define a parallel harness-only result protocol.

```text
CoreCycler parser / lifecycle terminal point
→ discovery terminal observation
→ discovery outcome classification and identity-bound result emission
→ parent verifies child exit and cleanup evidence
→ ordered suite reduction
→ discovery state transition and durable persistence
```

The production terminal-observation seam is entered only at existing CoreCycler terminal points:

- parser-confirmed workload completion, including the current Prime95 automatic-runtime, y-cruncher automatic-runtime, and fixed-runtime completion paths;
- classified stress/parser/WHEA/lifecycle error handling through the existing `Test-StressTestProgrammIsRunning` and `Resolve-StressTestProgrammIsRunningError` flow.

The observation records only facts available at that point: terminal kind, active core, stage log identity, parser evidence, and any existing error classification or lifecycle facts. A pure classifier converts that observation into one identity-bound discovery result. The result repeats the stage context identity and is emitted atomically; stale, duplicate, malformed, nonterminal, or mismatched artifacts are rejected.

The parent, not the terminal classifier, establishes child exit and cleanup facts after the child boundary. A result reaches suite reduction only when `childExited` and `expectedStressProcessCleanupVerified` are actual Boolean `true`. The authoritative finite stress-process identity source must be characterized from CoreCycler’s real lifecycle before it is committed to the protocol. Do not use host-wide image-name process discovery or speculative manifest fields.

A real harmless CoreCycler child is a transport/ownership test only. It uses this same observation, classification, emission, and result-reading machinery to prove launch ownership, PID/start-time binding, artifact transport, child exit, and cleanup. Its controlled terminal observation maps only to `INFRASTRUCTURE_INVALID`; it can never emit stability `PASS`.

## Evidence and transitions

| Evidence | Meaning | Boundary effect | Core action |
|---|---|---|---|
| `OBSERVED_PASS` | All four ordered workload stages passed after verified application | update `lastObservedPass` | advance exactly `-1`, or resolve at platform limit |
| `ATTRIBUTED_FAIL` | Positive trustworthy active-core instability attribution | set `firstObservedFail` | resolve to previous full-suite pass |
| `AMBIGUOUS_FAIL` | Disruptive evidence without trustworthy active-core causality | none | quarantine; do not automatically reapply suspect candidate |
| `INFRASTRUCTURE_INVALID` | Execution, lifecycle, parser, config, log, or protocol failure | none | recover and retry only with fresh trustworthy identity/evidence |

`ATTRIBUTED_FAIL` requires positive trustworthy active-core attribution, not merely a verified-idle-host assumption. It may be produced by:

- a direct workload calculation failure attributable to the active stage/core;
- equivalent CoreCycler `CALCULATIONERROR` evidence attributable to that stage/core;
- processor WHEA only when usable APIC/core mapping positively identifies the active core.

`AMBIGUOUS_FAIL` includes WHEA without trustworthy active-core attribution and disruptive evidence whose active-core causality remains uncertain.

`INFRASTRUCTURE_INVALID` includes process, lifecycle, parser, configuration, log, or protocol failures. `PROCESSMISSING` and `CPULOAD` are infrastructure-invalid unless concrete evidence independently demonstrates attributable silicon instability. A verified-idle-host model can support evidence collection and interpretation but cannot promote weak WHEA, process, or lifecycle evidence into `ATTRIBUTED_FAIL`.

If `ATTRIBUTED_FAIL` occurs before any observed pass, resolve as `NO_VALID_BASELINE`. If the platform minimum passes, resolve as `PLATFORM_LIMIT_REACHED`.

Controlled terminal observations in software-control tests exercise this production classification/emission seam. They prove control-flow and evidence gating, not hardware stability.

## Per-core state

Extend PR #182 state without overloading existing `confirmed` semantics.

```text
discovery:
  currentCandidate
  lastObservedPass
  firstObservedFail
  discoveryCandidate
  resolution
  candidateAttemptId
  attemptStatus
  workloadSetId
  stageIndex
  stageResults
  lastEvent
```

Resolution values:

- `DISCOVERY_CANDIDATE`
- `PLATFORM_LIMIT_REACHED`
- `NO_VALID_BASELINE`
- `QUARANTINED_AMBIGUOUS`
- existing `ignored` where appropriate

A discovery result must not be exported as `knownGoodValues` merely because isolated discovery completed.

## Persistence and resume

Reuse PR #182 `.automode`, backup generation, append-only results, remaining-order state, and recovery mechanisms.

```text
persist candidate + attempt identity
→ apply candidate
→ verify effective map
→ persist APPLIED_VERIFIED
→ start stage / establish fresh evidence boundary
→ collect and classify evidence
→ persist terminal transition
```

Recovery must preserve what the evidence supports:

- controlled/infrastructure interruption: no CPU conclusion; restore safe state and retry when trustworthy;
- unexplained disruptive interruption while a verified candidate was active: quarantine rather than manufacture a boundary or silently reapply;
- durably terminal attempt: never repeat or reinterpret it.

Recovered records must match their candidate/workload identity. Stale or torn state must not advance a core.

## Combined-map boundary

Isolated discovery does not validate the assembled map.

Combined-map validation may begin only when every included core has an actionable observed passing candidate. `QUARANTINED_AMBIGUOUS` and `NO_VALID_BASELINE` require resolution or exclusion first.

Combined-map validation uses fresh evidence and remains deferred until isolated discovery is trustworthy.
