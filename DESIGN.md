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

Use a synchronous rung barrier:

```text
0:   all unresolved cores
-1:  surviving unresolved cores
-2:  surviving unresolved cores
...
```

A core must earn the current rung before advancing. Resolved or quarantined cores leave the active set.

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

A candidate earns one `OBSERVED_PASS` only after every required stage passes within the same candidate attempt.

Current discovery suite:

1. y-cruncher Kagari: BKT, BBP, SFTv4, SNT, SVT, FFTv4, N63, VT3; 2 threads.
2. Prime95 SSE Huge FFT: 8960K–32768K; 1 thread.
3. Prime95 AVX2: 720K / 768K; 1 thread; 3 min/core.
4. Prime95 AVX2: 1344K; 1 thread; 3 min/core.

A valid attributable failure is fail-fast for that core/candidate.

Prefer a small coordinator reusing existing workload launch, affinity, completion, and parsing. Before choosing in-process stage switching, verify that CoreCycler's lifecycle can transition safely without invasive reset logic or stale state. Otherwise use the smallest hybrid orchestration preserving the same evidence contract.

## Evidence and transitions

| Evidence | Meaning | Boundary effect | Core action |
|---|---|---|---|
| `OBSERVED_PASS` | Full suite passed after verified application | update `lastObservedPass` | advance exactly `-1`, or resolve at platform limit |
| `ATTRIBUTED_FAIL` | Positive instability evidence attributable to active core | set `firstObservedFail` | resolve to previous full-suite pass |
| `AMBIGUOUS_FAIL` | Disruptive evidence without trustworthy core boundary | none | quarantine; do not automatically reapply suspect candidate |
| `INFRASTRUCTURE_INVALID` | Orchestration/process/parser/log/evidence failure or controlled interruption | none | recover and retry when trustworthy |

Attributable evidence may include direct workload calculation failures, equivalent CoreCycler calculation errors, or processor WHEA whose usable APIC mapping identifies the active core.

If `ATTRIBUTED_FAIL` occurs before any observed pass, resolve as `NO_VALID_BASELINE`. If the platform minimum passes, resolve as `PLATFORM_LIMIT_REACHED`.

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
