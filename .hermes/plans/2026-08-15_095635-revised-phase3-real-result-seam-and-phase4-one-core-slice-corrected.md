# Revised Phase 3 Real Result Seam and Phase 4 One-Core Slice Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Finish Phase 3 by connecting actual CoreCycler terminal parsing/lifecycle outcomes to the existing identity-bound discovery result and suite interfaces, then prove one core/one candidate can complete both successful and attributable-failure software control paths durably without hardware execution.

**Architecture:** Retain the fresh-child-per-workload model and all existing pure identity/state/suite contracts. First expose one small discovery terminal-emission seam at the real CoreCycler points where its parser/lifecycle already decides “completed” or raises an error; the seam turns a structured terminal observation into the existing `Test-DiscoveryStageResult`/`Resolve-DiscoverySuiteStage` input. Then make a harmless real child use that same emitter only for non-evidence infrastructure transport. Finally use controlled terminal observations through that production emitter and the real coordinator interfaces to prove complete-suite `OBSERVED_PASS` and attributable failure transitions, including atomic durable persistence.

**Tech Stack:** Windows PowerShell 5.1, Pester 3.4, CoreCycler/PR #182 PowerShell runtime, JSON, SHA-256 config fingerprints, atomic `.automode` persistence, Git.

---

## Current context and conclusions from source inspection

- Repository: `C:/Users/micro/OneDrive/Documents/GitHub/AutoCoreCycler`
- Branch: `feature/descending-co-discovery`
- Reference baseline: `pr182-baseline` at `62adeb76bd444dc7531a779e68905cb11f6839f2`
- Current Phase 1–2 discovery foundation is complete: isolated discovery state, schema-v2 persistence/recovery, candidate/stage freshness, and fail-closed state restoration.
- Current Phase 3 foundation is complete but isolated: config fingerprints, stage context/result identity checks, ordered suite reducer, child plan/readiness/observation, and the isolated child launch adapter.
- `helpers/discovery-stage.psm1` already accepts only `PASS`, `ATTRIBUTED_FAIL`, `AMBIGUOUS_FAIL`, or `INFRASTRUCTURE_INVALID` after matching candidate/stage/workload/core/candidate/config/log/PID/start-time evidence.
- `helpers/discovery-suite.psm1` already requires actual `[Bool] $true` for both `childExited` and `expectedStressProcessCleanupVerified`; only final ordered `PASS` produces `OBSERVED_PASS` and the exact one-rung decrement.
- `script-corecycler.ps1` has real existing terminal decisions that must become the production discovery seam:
  - **successful parser/lifecycle completion:** Prime95 automatic-runtime branch around lines 15854–15886, y-cruncher automatic-runtime branch around lines 16093–16124, and fixed-runtime completion around lines 16201–16224;
  - **error classification:** `Test-StressTestProgrammIsRunning` detects process/log/WHEA/CPU errors and throws an error type around lines 10686–11667; `Resolve-StressTestProgrammIsRunningError` receives that classified exception around lines 11690–11805.
- These points currently record legacy output/event log and invoke legacy ATM behavior where enabled. They do **not** emit a discovery result. The discovery seam must be additive and opt-in; it must not repurpose legacy `Add-CorePass`, `Test-AutomaticTestModeIncrease`, `confirmed`, or `knownGoodValues`.
- The ownership gap remains material: the current launch adapter can report `Launched = $true` but return no usable PID/context after a post-launch identity failure. A runtime bridge must clean up its exact returned child object before returning from such a failure, or block without emitting/accepting any result.

## Strategic correction from the prior plan

The harmless CoreCycler child remains necessary, but it is **not** the Phase 3 completion criterion. It proves:

```text
real child launch
→ observed PID/UTC start time
→ same terminal-emitter/artifact path
→ child exit
→ verified cleanup
→ existing suite interface
```

Its only outcome is non-evidence `INFRASTRUCTURE_INVALID`. It can never yield `PASS`.

Before Phase 3 closes, the implementation must also establish the production-compatible terminal seam by which real CoreCycler parser/lifecycle completion and classified errors produce discovery terminal observations and results. That seam is exercised non-hardware with controlled observations/fixtures through the same production result constructor/emitter—not by a second harness-specific result architecture.

## Non-negotiable invariants

1. Legacy ATM is uphill-only. Discovery must not change `Test-AutomaticTestModeIncrease`, legacy pass confirmation, error/reset, `maxValue`, or resume semantics.
2. One `PASS` means a parser/lifecycle completion observation from the actual CoreCycler terminal seam. A harmless child and an arbitrary JSON file can never manufacture it.
3. The parent accepts only a result that matches exact candidate/stage/workload/core/candidate/config fingerprint/log path/child PID/UTC start time.
4. A result can reach the suite reducer only after real child exit and actual-Boolean cleanup evidence. Stale/malformed/mismatched/nonterminal data is rejected.
5. A launched but unbound child remains owned by the adapter/runtime bridge. It must be boundedly cleaned up by exact process object/PID or block as an unverified hard failure; it must never become a suite result.
6. The source of expected stress-process cleanup identity must be discovered from the actual CoreCycler lifecycle before protocol fields are fixed. Do not predeclare speculative `expectedStressProcessIds` in a manifest.
7. The Phase 4 successful control test proves software control only: controlled apply/readback + controlled parser/lifecycle observations + actual pure coordinator/persistence. It is not a claim that hardware is stable.
8. A candidate is never re-applied after ambiguous disruption. Apply/readback must be exact before `APPLIED_VERIFIED`; failure is quarantined or retried according to existing discovery state semantics.

## Out of scope

- No real stress workload, hardware CO write/readback, UAC, scheduler/resume task, or BIOS/firmware operation in tests.
- No multi-core synchronous rung scheduler until the single-core slice passes its full gate.
- No duplicate parser, affinity, WHEA, CO tool, or broad process-cleanup implementation.
- No commit, stage, push, merge, tag, or rewrite of history without separate authorization.

## Task 1: Characterize the real CoreCycler terminal boundary before designing protocol fields

**Objective:** Identify the minimal structured information that the real success and error paths already know at the moment a discovery result would be emitted.

**Files:**
- Create: `tests/DiscoveryCoreCyclerTerminalCharacterization.Tests.ps1`
- Read/inspect only initially: `script-corecycler.ps1`

**Step 1: Isolate the exact terminal call sites**

Document in the test comments and implementation notes the current paths:

- auto Prime95 success: `uniquePassedFFTs.Count -eq fftSubarray.Count` → `core_finished` → optional `Add-CorePass`;
- auto y-cruncher success: `uniquePassedTests.Count -eq settings.yCruncher.tests.Count` → `core_finished` → optional `Add-CorePass`;
- fixed-runtime success: final `Test-StressTestProgrammIsRunning` check passes → `core_finished` → optional `Add-CorePass`;
- classified failure: `Test-StressTestProgrammIsRunning` produces `PROCESSMISSING`, `CALCULATIONERROR`, `CPULOAD`, `WHEAERROR`, or fallback and throws; `Resolve-StressTestProgrammIsRunningError` receives it before legacy ATM increase/restart behavior.

**Step 2: Write failing characterization tests**

Use narrowly extracted/controlled invocation seams (not full CoreCycler startup) to demonstrate the terminal boundary can provide a record shaped like:

```powershell
@{
    TerminalKind       = 'COMPLETED' # or 'STRESS_ERROR'
    ErrorType          = $null       # or exact existing classifier text
    CoreNumber         = 2
    LogPath            = $stageLogPath
    StressProcess      = <existing lifecycle object or $null>
    ParserEvidence     = <existing terminal parser facts>
}
```

The test must *not* decide final discovery outcomes yet. It establishes what is truly available at success/error points and whether lifecycle ownership/cleanup facts exist there or must be supplied by the parent after child exit.

**Step 3: Run RED**

Run:

```bash
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Import-Module Pester -MinimumVersion 3.4.0; Invoke-Pester -Script @{Path='tests\\DiscoveryCoreCyclerTerminalCharacterization.Tests.ps1'}"
```

Expected: FAIL because no isolated terminal-observation seam exists.

**Step 4: Extract only the terminal observation seam**

Add a small function in `script-corecycler.ps1` or, if direct extraction preserves legacy behavior more safely, `helpers/discovery-corecycler-terminal.psm1`:

```powershell
New-CoreCyclerTerminalObservation \
  -TerminalKind <COMPLETED|STRESS_ERROR|SCRIPT_ERROR> \
  -CoreNumber <int> \
  -LogPath <string> \
  -ErrorType <string-or-null> \
  -ParserEvidence <hashtable-or-null>
```

Rules:

- It only captures facts at the established terminal point; it does not apply CO, launch/stop processes, mutate ATM state, call the suite coordinator, or write discovery state.
- It must distinguish parser-confirmed completion from a mere elapsed timer or child exit.
- It must preserve the exact legacy branches and invoke no code unless discovery protocol mode is explicitly active.
- Its input/output must make clear whether expected stress-process identity is actually available there. Do not invent it.

**Step 5: Run GREEN and legacy characterization**

Run new characterization tests plus existing focused config/ATM tests relevant to the touched functions. Expected: the observation seam is demonstrably derived from existing terminal paths and leaves legacy behavior unchanged when discovery is inactive.

## Task 2: Define outcome classification from real terminal observations

**Objective:** Create the single production result-classification function used by both real CoreCycler terminal paths and the harmless child transport test.

**Files:**
- Create: `helpers/discovery-corecycler-terminal.psm1` if not created in Task 1
- Create: `tests/DiscoveryCoreCyclerTerminalResult.Tests.ps1`
- Modify: `helpers/discovery-stage.psm1` only if a concrete missing result validation field is shown

**Step 1: Write failing classification tests**

Tests feed controlled terminal observations that mimic the existing CoreCycler parser/lifecycle outputs:

```powershell
$terminalResult = ConvertFrom-CoreCyclerTerminalObservation \
  -Context $context \
  -Observation $observation
```

Required controlled cases:

| Observation | Expected discovery outcome |
|---|---|
| parser-confirmed completion for exactly the bound stage | `PASS` |
| direct workload calculation failure, or equivalent CoreCycler `CALCULATIONERROR`, positively attributable to the active stage/core | `ATTRIBUTED_FAIL` |
| processor WHEA with usable APIC/core mapping that positively identifies the active core | `ATTRIBUTED_FAIL` |
| WHEA without trustworthy active-core attribution, or disruptive evidence whose active-core causality remains uncertain | `AMBIGUOUS_FAIL` |
| `PROCESSMISSING`, `CPULOAD`, script/adapter/config/log/protocol/lifecycle failure, or other unclassifiable execution evidence | `INFRASTRUCTURE_INVALID` |
| harmless protocol completion | `INFRASTRUCTURE_INVALID`, never `PASS` |

A verified-idle-host model may strengthen confidence in evidence collection, but it must not by itself promote `AMBIGUOUS_FAIL` or `INFRASTRUCTURE_INVALID` evidence into `ATTRIBUTED_FAIL`. The classifier must return the strongest conclusion positively supported by the terminal evidence.

Each output must include existing identity fields, `outcome`, and a narrow `terminalEvidence` record. Inputs that lack parser confirmation, conflict with the stage log, or use an unknown terminal kind must be rejected rather than defaulting to `PASS`.

**Step 2: Run RED**

Run `tests/DiscoveryCoreCyclerTerminalResult.Tests.ps1`; expected fail because the classifier does not exist.

**Step 3: Implement narrow classification**

Implement a pure result constructor that accepts only a validated stage context plus structured observation. It should output the same result shape already consumed by `Test-DiscoveryStageResult` and `Resolve-DiscoverySuiteStage`:

```powershell
@{
    candidateAttemptId = $Context.candidateAttemptId
    stageAttemptId     = $Context.stageAttemptId
    workloadId         = $Context.workloadId
    coreNumber         = $Context.coreNumber
    candidate          = $Context.candidate
    configFingerprint  = $Context.configFingerprint
    logPath            = $Context.logPath
    childProcessId     = $Context.childProcessId
    startedAt          = $Context.startedAt
    outcome            = 'PASS' # controlled strictly by terminal observation
    terminalEvidence   = <bounded structured evidence>
}
```

Do not add child-exit or cleanup fields here: those are parent/runtime facts established after child execution. Do not speculate about stress PID placement. If Task 1 finds the child has reliable process IDs at terminal time, document the exact data shape; if not, let the parent discover/verify cleanup from the established process lifecycle after exit.

**Step 4: Run GREEN**

Run the new classifier tests and `tests/DiscoveryStageEvidence.Tests.ps1` / `tests/DiscoverySuiteCoordinator.Tests.ps1`. Expected: existing stale-result checks still reject altered identity and no observation can yield an unauthenticated PASS.

## Task 3: Add a thin, opt-in CoreCycler result-emission hook at actual terminal points

**Objective:** Wire the production classification seam to every current relevant CoreCycler terminal branch without changing legacy outcomes.

**Files:**
- Modify: `script-corecycler.ps1`
- Modify: `helpers/discovery-corecycler-terminal.psm1`
- Create: `tests/DiscoveryCoreCyclerTerminalHook.Tests.ps1`
- Modify: `tests/DiscoveryStageConfigContract.Tests.ps1`

**Step 1: Write failing hook tests**

Test with controlled terminal-observation injection—not a real workload—that each branch calls the same opt-in emission hook:

- Prime95 automatic completion;
- y-cruncher automatic completion;
- fixed-runtime completion;
- a caught `StressTestError` routed through `Resolve-StressTestProgrammIsRunningError`.

Assert exact terminal outcome mapping and that inactive discovery mode does not call the hook or change legacy `Add-CorePass`/`Test-AutomaticTestModeIncrease` calls.

**Step 2: Run RED**

Run `tests/DiscoveryCoreCyclerTerminalHook.Tests.ps1`; expected fail due to missing hook.

**Step 3: Implement one emission hook**

Add an optional explicit discovery-stage input, but keep its early validation and artifact schema minimal until lifecycle findings are known. The hook must:

1. be active only when an explicit discovery stage invocation is present;
2. build a terminal observation from the real success/failure call site;
3. classify it only via `ConvertFrom-CoreCyclerTerminalObservation`;
4. write a terminal artifact atomically after identity validation;
5. leave legacy output/event log/state transitions in their existing order and semantics;
6. ensure one child stage produces at most one terminal artifact; duplicate/missing/failing artifact promotion is `INFRASTRUCTURE_INVALID`, never a silent second result.

The artifact schema must repeat the existing context identity and carry the classifier’s `terminalEvidence`. It must not predeclare `expectedStressProcessIds` until Task 4 resolves lifecycle ownership.

**Step 4: Run GREEN and static checks**

Run hook/config contract tests, parser checks on `script-corecycler.ps1`, and CRLF-aware diff check. Expected: one shared production hook covers all known completion/error branches and normal CoreCycler invocation is unaffected.

## Task 4: Establish actual child/stress lifecycle cleanup evidence and close ownership gaps

**Objective:** Determine the narrow authoritative source of cleanup facts, then ensure the bridge never accepts a result without verified child exit and expected stress cleanup.

**Files:**
- Modify: `helpers/discovery-child-launch.psm1`
- Create: `helpers/discovery-stage-runtime.psm1`
- Create: `tests/DiscoveryChildOwnership.Tests.ps1`
- Create: `tests/DiscoveryStageLifecycleEvidence.Tests.ps1`
- Modify: `tests/DiscoveryChildExecutor.Tests.ps1`

**Step 1: Write failing ownership tests**

Required cases:

```powershell
# Started child but unreadable/nonpositive/non-[Int] PID.
$launch.Launched | Should Be $true
$launch.Context | Should Be $null
$launch.CleanupVerified | Should Be $true
$launch.Reason | Should Be 'child_process_identity_unavailable'

# Valid PID, unreadable/non-UTC start time.
$launch.ChildProcessId | Should Be 4242
$launch.Context | Should Be $null
$launch.CleanupVerified | Should Be $true
$launch.Reason | Should Be 'child_start_time_unavailable'
```

Also write failure tests around lifecycle evidence: missing result, child timeout, nonzero child exit, invalid artifact, and unresolved expected stress process. The tests must prove no suite call is made on any of those paths.

**Step 2: Run RED**

Run the ownership/lifecycle test files. Expected: current adapter retains a started child but does not perform bridge-owned cleanup.

**Step 3: Implement exact owned-child compensation**

Add a private bounded cleanup helper operating only on the returned `System.Diagnostics.Process` object (or exactly verified returned PID when object operations are unavailable). Never enumerate or kill image-name matches.

Extend the launch envelope minimally:

```powershell
@{
    Launched        = [bool]
    Reason          = [string]
    ChildProcessId  = [int] or $null
    Context         = <context> or $null
    Process         = <process object> or $null
    CleanupVerified = [bool] or $null
}
```

On a post-launch binding failure, attempt compensating cleanup immediately. If exit cannot be proven, return an explicitly unverified failure and block all result processing.

**Step 4: Resolve where expected stress-process identity truly comes from**

Characterize the real current lifecycle rather than guessing:

- At normal success/error hooks, inspect what CoreCycler retains (`$stressTestProcess`, `$stressTestProcessId`, adapter-specific process identity, and `Close-StressTestProgram`/exit behavior).
- Determine whether an explicit child artifact can truthfully report an expected process identity, whether the parent can verify a finite child-owned set after child exit, or whether the safe first production rule is an empty/no-created-stress set only for the harmless mode.
- Record the selected source and its validation in code/test comments and `DECISIONS.md` only after the characterization proves it.

Do not broaden cleanup to host-wide process discovery. A verified-idle-host model may be used only as a bounded evidence-collection assumption where the real lifecycle requires it; it does not upgrade otherwise ambiguous or infrastructure evidence into active-core instability. Recovery durability and reader integrity remain mandatory.

**Step 5: Implement lifecycle gate**

`Invoke-DiscoveryStageRuntimeBridge` must:

1. launch via the existing plan adapter;
2. require valid observed context;
3. wait for exact child exit within a bounded timeout;
4. read/validate exactly one terminal artifact from the Task 3 production emitter;
5. establish cleanup evidence from the Task 4 characterized source;
6. add actual `[Bool]` `childExited` and `expectedStressProcessCleanupVerified` to the classifier result;
7. refuse suite input if either is not actual `$true`.

**Step 6: Run GREEN**

Run child launch/observation/executor/ownership/lifecycle tests together. Verify a successful bridge has exact bound identity and verified cleanup, and every uncertainty is fail-closed.

## Task 5: Prove real child transport with a harmless non-evidence invocation

**Objective:** Exercise child launch, observed identity, the same terminal artifact writer/reader, exit/cleanup gate, and suite interface without a real stress workload or fabricated PASS.

**Files:**
- Modify: `script-corecycler.ps1`
- Modify: `helpers/discovery-stage-runtime.psm1`
- Create: `tests/DiscoveryCoreCyclerHarmlessBridge.Tests.ps1`
- Modify: `tests/DiscoveryCoreCyclerTerminalHook.Tests.ps1`

**Step 1: Write failing harmless-child test**

Invoke the actual `script-corecycler.ps1` with the explicit discovery-stage input in a temporary directory. It must take a dedicated early harmless route before normal CoreCycler initialization, stress startup, CO application, scheduler/resume, or `.automode` writes.

Assert:

```powershell
$bridge.Context.childProcessId | Should BeGreaterThan 0
$bridge.Context.startedAt.Kind | Should Be ([DateTimeKind]::Utc)
$bridge.Result.outcome | Should Be 'INFRASTRUCTURE_INVALID'
$bridge.Result.childExited | Should Be $true
$bridge.Result.expectedStressProcessCleanupVerified | Should Be $true
$bridge.SuiteDecision.Disposition | Should Be 'RETRY_REQUIRES_FRESH_STAGE_IDENTITY'
```

Also assert no normal CoreCycler/stress/CO artifacts are created and no transition becomes `OBSERVED_PASS`.

**Step 2: Run RED**

Run only the harmless bridge test; expected fail because the opt-in harmless protocol path does not exist.

**Step 3: Implement the harmless route through the production emitter**

The route may produce a controlled observation whose explicit terminal kind maps only to `INFRASTRUCTURE_INVALID`. It must invoke the **same** `ConvertFrom-CoreCyclerTerminalObservation` and artifact writer from Tasks 2–3. Do not add a harness-specific result schema or reader.

**Step 4: Run GREEN**

Run harmless bridge, terminal hook/classifier, runtime lifecycle, and suite tests. Expected: real process transport works; harmless execution cannot produce PASS.

## Task 6: Finish Phase 3 with controlled real-result seam coverage

**Objective:** Demonstrate that the actual production result classifier/emitter produces suite-ready PASS and failure inputs from controlled parser/lifecycle fixtures without operating hardware.

**Files:**
- Modify: `tests/DiscoveryCoreCyclerTerminalResult.Tests.ps1`
- Modify: `tests/DiscoveryCoreCyclerTerminalHook.Tests.ps1`
- Modify: `tests/DiscoveryStageLifecycleEvidence.Tests.ps1`
- Modify: `tests/DiscoverySuiteCoordinator.Tests.ps1`

**Step 1: Write controlled terminal-fixture tests**

Feed the same production terminal-observation/classification/emission API controlled facts corresponding to:

- Prime95 completion evidence;
- y-cruncher completion evidence;
- fixed-runtime completion evidence;
- direct workload calculation failure / equivalent CoreCycler `CALCULATIONERROR` positively attributable to the active stage/core;
- processor WHEA with usable APIC/core mapping positively identifying the active core;
- WHEA or disruptive evidence without trustworthy active-core attribution;
- `PROCESSMISSING`, `CPULOAD`, lifecycle/protocol/config/log failure, and malformed/missing evidence.

For valid controlled completion, prove resulting `PASS` passes `Test-DiscoveryStageResult` only with matching context and verified lifecycle fields. For positively attributable calculation-error or APIC-mapped WHEA evidence, prove `ATTRIBUTED_FAIL` reaches `Resolve-DiscoverySuiteStage`. Prove unattributed WHEA remains `AMBIGUOUS_FAIL`, and process/lifecycle/infrastructure failures remain `INFRASTRUCTURE_INVALID`. This is not a hardware PASS; it is proof the real production result seam maps its own parser/lifecycle semantics correctly.

**Step 2: Run RED**

Run the modified tests before implementation gaps are filled. Expected failure should be an absent/unwired production observation/emission case, not an unrelated full-runtime startup failure.

**Step 3: Complete only missing production seam coverage**

Fix only concrete gaps found by the fixtures. Do not introduce a second parser or bypass the actual terminal-emission API.

**Step 4: Run the Phase 3 focused gate**

```bash
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Import-Module Pester -MinimumVersion 3.4.0; Invoke-Pester -Script @{Path='tests\\DiscoveryStageEvidence.Tests.ps1'},@{Path='tests\\DiscoverySuiteCoordinator.Tests.ps1'},@{Path='tests\\DiscoveryChildLaunchPlan.Tests.ps1'},@{Path='tests\\DiscoveryChildObservation.Tests.ps1'},@{Path='tests\\DiscoveryChildExecutor.Tests.ps1'},@{Path='tests\\DiscoveryChildOwnership.Tests.ps1'},@{Path='tests\\DiscoveryCoreCyclerTerminalCharacterization.Tests.ps1'},@{Path='tests\\DiscoveryCoreCyclerTerminalResult.Tests.ps1'},@{Path='tests\\DiscoveryCoreCyclerTerminalHook.Tests.ps1'},@{Path='tests\\DiscoveryStageLifecycleEvidence.Tests.ps1'},@{Path='tests\\DiscoveryCoreCyclerHarmlessBridge.Tests.ps1'} -PassThru"
```

**Phase 3 completion gate:**

- production terminal seam covers known CoreCycler completion/error branches;
- controlled fixtures prove `PASS`, `ATTRIBUTED_FAIL`, `AMBIGUOUS_FAIL`, and `INFRASTRUCTURE_INVALID` mapping through that same seam, with `ATTRIBUTED_FAIL` limited to positive trustworthy active-core instability attribution;
- actual harmless child proves ownership/identity/artifact/exit/cleanup transport and never emits PASS;
- stale/malformed/timeout/unbound/cleanup-uncertain cases never reach the suite;
- legacy CoreCycler/ATM behavior remains intact when discovery mode is off.

Stop Phase 3 here unless tests reveal a concrete blocker. Do not build more scheduler functionality.

## Task 7: Characterize only Phase 4 shared CO/apply/readback seams

**Objective:** Discover the smallest existing CoreCycler mechanisms needed for one core/one candidate controlled apply/readback verification.

**Files:**
- Create: `tests/DiscoveryPhase4Characterization.Tests.ps1`
- Read/inspect only initially: `script-corecycler.ps1`, relevant existing helper files/tests

**Step 1: Locate exact existing seams**

Inspect and characterize only:

- tested-core isolation-map construction and `setVoltageOnlyForTestedCore` behavior;
- existing `Set-NewVoltageValues`/CO application primitive;
- any actual effective-map readback/normalization mechanism;
- scalar `startValues = 0` compatibility only if it blocks the one-core branch;
- legacy `Add-CorePass`, `Test-AutomaticTestModeIncrease`, error/reset, and resume behavior if the selected shared seam touches them.

**Step 2: Write non-hardware baseline characterization tests**

Use controlled adapter doubles to show:

- intended map construction is distinct from verified effective-map readback;
- legacy ATM’s uphill logic remains separate;
- discovery candidate state cannot be mistaken for legacy confirmed state;
- one-core isolation does not mutate non-target discovery policy state.

**Step 3: Run and record only demonstrated blockers**

If no narrow reusable readback seam exists, record the concrete blocker in `ISSUES.md` and update this plan before adding a replacement abstraction. Do not infer behavior from names alone.

## Task 8: Add a pure one-core candidate selection and apply/readback gate

**Objective:** Allow an opt-in discovery request to select one candidate, apply it through a controlled adapter, and transition only after exact effective-map verification.

**Files:**
- Create: `helpers/discovery-phase4.psm1`
- Create: `tests/DiscoveryPhase4Policy.Tests.ps1`
- Create: `tests/DiscoveryPhase4ApplyReadback.Tests.ps1`
- Modify: `helpers/discovery-state.psm1` only if a missing pure transition is proven
- Modify: the specific characterized CO seam only if required

**Step 1: Write failing policy tests**

```powershell
$request = New-DiscoverySingleCandidateRequest \
  -State $state \
  -CoreNumber 2 \
  -Candidate -18
```

Reject terminal, quarantined, retry-required, candidate-mismatched, or multi-core requests. It must not launch a child, apply a value, mutate legacy ATM state, or persist.

**Step 2: Run RED; add minimal pure policy; run GREEN**

Keep selection policy separate from legacy ATM and return a narrow request envelope.

**Step 3: Write failing apply/readback tests**

Use controlled doubles around the characterized existing apply/readback seam:

```powershell
$applyDecision = Invoke-DiscoveryCandidateApplyAndReadback \
  -Request $request \
  -ApplyAdapter $applyAdapter \
  -ReadbackAdapter $readbackAdapter
```

Required assertions:

- exact target-core map and explicit safe non-target values are requested;
- apply failure cannot yield `APPLIED_VERIFIED`;
- absent/mismatched readback cannot yield `APPLIED_VERIFIED` or stage launch;
- exact normalized readback transitions exactly that candidate attempt to `APPLIED_VERIFIED`;
- ambiguous interruption after verified application follows quarantine and does not reapply;
- legacy ATM outcome is unchanged in characterization tests.

**Step 4: Run RED; implement the smallest adapter; run GREEN**

The adapter returns a decision envelope only. It does not perform real hardware work in tests and does not route discovery through legacy `confirmed` paths.

## Task 9: Compose a full successful one-core/one-candidate software-control path

**Objective:** Prove controlled apply/readback plus a complete ordered required suite yields `OBSERVED_PASS`, persists it atomically, and advances exactly one rung.

**Files:**
- Modify: `helpers/discovery-phase4.psm1`
- Modify: `helpers/discovery-stage-runtime.psm1`
- Create: `tests/DiscoveryPhase4SuccessfulVerticalSlice.Tests.ps1`
- Modify: `tests/DiscoveryPersistenceContract.Tests.ps1`
- Modify: `tests/DiscoverySuiteCoordinator.Tests.ps1`

**Step 1: Write one failing complete-suite test**

Start a state for one core with candidate `-18`, the canonical complete required discovery suite, and fresh distinct candidate/stage IDs. The suite must contain all four required stages in order:

1. y-cruncher Kagari: BKT, BBP, SFTv4, SNT, SVT, FFTv4, N63, VT3; 2 threads;
2. Prime95 SSE Huge FFT: 8960K–32768K; 1 thread;
3. Prime95 AVX2: 720K / 768K; 1 thread; 3 min/core;
4. Prime95 AVX2: 1344K; 1 thread; 3 min/core.

The test must consume the same canonical workload-set definition used by production discovery rather than maintaining a shortened or independent acceptance-test list. If no canonical definition exists yet, establish the smallest single source of truth as part of the Phase 4 composition work before this gate can pass.

Use:

- controlled apply adapter;
- controlled exact readback adapter;
- the Task 2/3 real terminal observation → classifier → emitter → reader interface with controlled parser-completion observations;
- real `Resolve-DiscoverySuiteStage` calls;
- existing atomic discovery snapshot conversion/persistence path in a temporary `.automode` generation.

Assert the exact ordered flow:

```text
core 2 / candidate -18
→ apply + exact effective-map readback
→ APPLIED_VERIFIED
→ controlled real-result seam PASS for y-cruncher Kagari
→ ADVANCE_STAGE only to Prime95 SSE Huge FFT
→ controlled real-result seam PASS for Prime95 SSE Huge FFT
→ ADVANCE_STAGE only to Prime95 AVX2 720K / 768K
→ controlled real-result seam PASS for Prime95 AVX2 720K / 768K
→ ADVANCE_STAGE only to Prime95 AVX2 1344K
→ controlled real-result seam PASS for Prime95 AVX2 1344K
→ complete-suite OBSERVED_PASS
→ lastObservedPass = -18
→ currentCandidate = -19        # exactly -1
→ atomic durable restored state preserves -19 and identities
```

Assert that PASS is supplied only through the Task 2 production classifier/emitter fixture path, not by hand-building a suite result hashtable in the vertical slice.

**Step 2: Run RED**

Run:

```bash
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Import-Module Pester -MinimumVersion 3.4.0; Invoke-Pester -Script @{Path='tests\\DiscoveryPhase4SuccessfulVerticalSlice.Tests.ps1'}"
```

Expected: fail because the Phase 4 composed control adapter does not exist.

**Step 3: Implement only composition glue**

Implement a narrow coordinator facade that sequences:

1. pure candidate selection;
2. apply/readback verification;
3. stage request/context/production terminal-result intake;
4. existing suite reducer;
5. existing persistence only after accepted transitions.

It must not add a scheduler, a new state engine, or alternate result parsing.

**Step 4: Run GREEN and recovery regression**

Run the successful slice, suite coordinator, discovery state, and persistence contract tests. Verify current candidate is exactly `-19` after restore—not merely before serialization.

## Task 10: Compose an attributable-failure one-core path

**Objective:** Prove the same composed control path records an attributable candidate boundary/failure correctly and does not advance/reapply it.

**Files:**
- Create: `tests/DiscoveryPhase4AttributedFailureVerticalSlice.Tests.ps1`
- Modify: `helpers/discovery-phase4.psm1` only if a composition gap is exposed
- Modify: `tests/DiscoveryPersistenceContract.Tests.ps1`

**Step 1: Write failing attributable-failure test**

Set initial durable state with prior observed pass `-18`, current candidate `-19`, `APPLIED_VERIFIED`, and fresh stage IDs. Use controlled exact readback and feed an attributable parser/lifecycle observation through the **same production classifier/emitter interface**.

Assert:

```text
ATTRIBUTED_FAIL
→ CANDIDATE_EVIDENCE_RECORDED
→ firstObservedFail = -19
→ discoveryCandidate = -18
→ resolution = DISCOVERY_CANDIDATE
→ no later workload stage
→ no retry/reapply request
→ atomic durable restoration retains that boundary
```

Also cover a first-candidate attributable failure that produces `NO_VALID_BASELINE` rather than inventing a prior pass.

**Step 2: Run RED; implement minimal glue; run GREEN**

No new failure parser is allowed here. Fix only a demonstrated composition or persistence gap.

## Task 11: Review, document, and stop before scheduler generalization

**Objective:** Complete non-hardware acceptance for the trusted single-core mechanism and retain a clear boundary before synchronous multi-core progression.

**Files:**
- Modify only after fresh passing evidence: `PLAN.md`, `ISSUES.md`, `DECISIONS.md`, and affected `docs/wiki/` pages.

**Step 1: Run final gates**

```bash
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Import-Module Pester -MinimumVersion 3.4.0; $result=Invoke-Pester -Script @{Path='tests'} -PassThru; Write-Output ('Passed=' + $result.PassedCount); Write-Output ('Failed=' + $result.FailedCount); if($result.FailedCount -ne 0){exit 1}"

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$paths=@('helpers\\discovery-state.psm1','helpers\\discovery-stage.psm1','helpers\\discovery-suite.psm1','helpers\\discovery-child-launch.psm1','helpers\\discovery-corecycler-terminal.psm1','helpers\\discovery-stage-runtime.psm1','helpers\\discovery-phase4.psm1','script-corecycler.ps1'); foreach($path in $paths){ if(Test-Path -LiteralPath $path){$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path),[ref]$tokens,[ref]$errors)|Out-Null;if($errors.Count){$errors;exit 1}} }"

git -c core.whitespace=cr-at-eol diff --check
git diff --stat
git status --short
```

**Step 2: Conduct two independent reviews, in order**

1. **Spec compliance review:** confirms real terminal hooks cover parser/lifecycle completion and error paths; controlled result fixtures use production interfaces; child ownership/cleanup and stale evidence gates hold; success gives exactly `-1`; attributable failure preserves the correct boundary; legacy ATM is untouched.
2. **Quality/safety review:** examines process ownership, timeout/cleanup behavior, atomic terminal artifact and `.automode` writes, strict types, TOCTOU/stale boundaries, error classification, tests, and unnecessary shared-path divergence.

Material findings require a new focused failing regression, minimal repair, and repeat review.

**Step 3: Update factual documentation only**

Document:

- the actual CoreCycler terminal points now used by discovery;
- the established cleanup-evidence source and its limitations;
- harmless-child evidence as transport-only;
- controlled-complete-suite and attributable-failure software acceptance results as non-hardware evidence;
- deferred work: multi-core synchronous rung scheduler, restart/resume integration after validated policy seam, and supervised hardware trial.

**Stop gate:** Do not generalize to multi-core rungs or schedule a hardware trial until all of these are true:

- actual CoreCycler terminal parser/lifecycle seam emits the stage result interface;
- a real harmless child proves process transport but cannot emit PASS;
- controlled production-seam observations prove complete suite PASS → `OBSERVED_PASS` → durable exact `-1` transition;
- controlled production-seam attributable failure proves correct durable boundary/no-reapply behavior;
- child identity, exit, cleanup, config/log/result freshness, and legacy ATM isolation pass independent review.

## Likely files

### Create

- `helpers/discovery-corecycler-terminal.psm1`
- `helpers/discovery-stage-runtime.psm1`
- `helpers/discovery-phase4.psm1`
- `tests/DiscoveryCoreCyclerTerminalCharacterization.Tests.ps1`
- `tests/DiscoveryCoreCyclerTerminalResult.Tests.ps1`
- `tests/DiscoveryCoreCyclerTerminalHook.Tests.ps1`
- `tests/DiscoveryChildOwnership.Tests.ps1`
- `tests/DiscoveryStageLifecycleEvidence.Tests.ps1`
- `tests/DiscoveryCoreCyclerHarmlessBridge.Tests.ps1`
- `tests/DiscoveryPhase4Characterization.Tests.ps1`
- `tests/DiscoveryPhase4Policy.Tests.ps1`
- `tests/DiscoveryPhase4ApplyReadback.Tests.ps1`
- `tests/DiscoveryPhase4SuccessfulVerticalSlice.Tests.ps1`
- `tests/DiscoveryPhase4AttributedFailureVerticalSlice.Tests.ps1`

### Modify

- `script-corecycler.ps1`
- `helpers/discovery-child-launch.psm1`
- `helpers/discovery-stage.psm1` only for a demonstrated missing validation field
- `helpers/discovery-suite.psm1` only if a proven production result boundary requires a minimal compatible contract change
- existing discovery tests and persistence contracts
- factual plan/issue/decision/wiki documents after passing gates

## Risks and controls

| Risk | Control |
|---|---|
| Harness architecture diverges from real CoreCycler results | Harness calls the exact production terminal result classifier/emitter and is limited to `INFRASTRUCTURE_INVALID`. |
| PASS comes from child exit, timer, or arbitrary JSON | `PASS` is allowed only from a controlled/real parser-confirmed completion observation at the production terminal seam; artifact identity and lifecycle fields are independently verified. |
| Child cannot bind identity after it starts | Exact returned process object is cleaned with a bounded protocol; unverified cleanup blocks all suite input. |
| Cleanup PIDs are speculative or unsafe | Characterize the real CoreCycler lifecycle first; use only its demonstrated finite identity source, never broad image-name cleanup. |
| Error mapping changes legacy behavior | Additive opt-in hook at existing terminal points; baseline tests keep `Add-CorePass` and `Test-AutomaticTestModeIncrease` semantics unchanged when discovery is off. |
| Controlled PASS tests overclaim hardware stability | Tests explicitly use controlled production-seam observations and adapters; no stress workload or CO hardware action runs. |
| Overbuilding Phase 3 or scheduler early | Stop Phase 3 after real terminal seam + harmless transport + failure gates; stop Phase 4 after one-core success/failure persistence gates. |

## Open questions resolved by evidence during execution

1. Which exact CoreCycler lifecycle object(s) yield trustworthy expected stress-process cleanup evidence at the child terminal boundary?
2. Is a child-declared finite expected stress process set needed, or can cleanup be established from already existing per-adapter child lifecycle state after child exit?
3. Does existing CO infrastructure expose a normalized effective-map readback seam suitable for a controlled adapter? If not, what minimal shared extraction preserves legacy behavior?
4. Which existing artifact directory is the safest result target once current log-path lifecycle and artifact atomicity are characterized?

Do not answer these by assumption; decide and document only after the relevant focused characterization tests prove the actual source behavior.
