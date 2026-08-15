# Phase 3 Runtime Bridge and Phase 4 Vertical Slice Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Close Phase 3 with the smallest trustworthy child-to-suite runtime bridge, then build one non-hardware Phase 4 vertical slice that applies and verifies one candidate before its required suite can affect durable discovery state.

**Architecture:** Keep legacy `script-corecycler.ps1` and uphill ATM behavior intact. Add a discovery-specific, manifest-backed stage protocol that uses one real but harmless CoreCycler child to prove process identity, a bound terminal artifact, child exit, and owned-process cleanup without manufacturing stability evidence. Feed only verified, stage-scoped terminal evidence into the existing pure suite reducer. After Phase 3 closes, add a separate opt-in one-core/one-candidate policy seam that reuses the existing CO apply/readback mechanism behind an explicit effective-map gate.

**Tech Stack:** Windows PowerShell 5.1, Pester 3.4, PowerShell modules, CoreCycler/PR #182 runtime, JSON files, SHA-256 config-byte fingerprints, Git.

---

## Scope and current facts

- Repository: `C:/Users/micro/OneDrive/Documents/GitHub/AutoCoreCycler`
- Authorized branch: `feature/descending-co-discovery`
- Reference baseline: `pr-182` / `pr182-baseline^{commit}` at `62adeb76bd444dc7531a779e68905cb11f6839f2`
- Current Phase 3 foundations already exist:
  - `helpers/discovery-state.psm1` — pure transitions, schema v2 snapshots, retry/recovery identities;
  - `helpers/discovery-stage.psm1` — config fingerprint, context, terminal identity validation;
  - `helpers/discovery-suite.psm1` — ordered stage reducer and strict lifecycle gate;
  - `helpers/discovery-child-launch.psm1` — deterministic plan, readiness, observed identity binding, and isolated `Start-DiscoveryStageChildFromPlan`;
  - `script-corecycler.ps1` — optional explicit `-ConfigPath` and optional discovery-state persistence.
- The current child adapter can report a successful launch without a bindable PID or start time. That is not safe for a bridge that owns a real child: an unbound child must be synchronously cleaned up or cause a hard stop, never become a suite result.
- No Phase 3 runtime coordinator, parser/result bridge, real CoreCycler child integration, CO application, scheduler/resume flow, UAC action, stress workload, or hardware operation is authorized by this plan alone.
- Do not modify installed CoreCycler or the Hermes CoreCycler skill. Do not commit, stage, push, merge, tag, or rewrite history without separate authorization.

## Non-negotiable invariants

1. Legacy ATM remains uphill-only; do not reuse `confirmed`, `knownGoodValues`, `maxValue`, or `Test-AutomaticTestModeIncrease` as descending discovery policy.
2. A stability `PASS` must originate from a real workload/parser path after verified CO application. A harmless protocol child must never emit evidence that can advance a candidate.
3. A suite result must bind the exact candidate/stage IDs, workload, config fingerprint, log identity, child PID, and UTC start time.
4. The coordinator may advance only after actual child exit and exact Boolean cleanup evidence for the expected stress processes.
5. Any missing/malformed/stale manifest or result, nonzero child exit, uncertain PID/start time, timeout, or uncertain cleanup is `INFRASTRUCTURE_INVALID` or a hard bridge failure; neither may advance discovery.
6. If a child has started but identity cannot be bound, the runtime bridge owns compensating cleanup using the returned process object; it must not return an untracked live child to a caller.
7. Phase 4 may not apply/reapply a candidate until a discovery-specific policy path selects it and an effective-map readback verifies it. An unexplained disruptive candidate is quarantined rather than silently reapplied.
8. All non-hardware tests use temporary directories and harmless child scripts only. Do not run `script-corecycler.ps1` normal workload mode, stress programs, CO writes, UAC elevation, scheduler/resume actions, or hardware operations as test verification.

## Explicit non-goals for this plan

- No generalized discovery framework, telemetry system, environment inventory, or new stress engine.
- No real stability PASS from a synthetic/harness child.
- No multi-core rung scheduler until the one-core/one-candidate vertical slice is trustworthy.
- No combined-map validation, hardware trial, or automatic cross-reboot privilege persistence.
- No duplicated CoreCycler parser, affinity, WHEA, CO, or stress-process implementation.

## Proposed bridge shape

Add one discovery-specific **stage manifest / terminal artifact protocol**. A future coordinator writes a fresh stage manifest and result target outside the repository root config. `script-corecycler.ps1` accepts the manifest only through an opt-in discovery argument; normal invocation remains unchanged.

For the initial non-hardware bridge, the child protocol exits before normal CoreCycler workload/CO/runtime initialization and writes an identity/config-bound **harness attestation**, not a `PASS`. The parent waits for actual child exit, verifies the empty expected-stress-process set declared by the harness, and maps the result to `INFRASTRUCTURE_INVALID`. This exercises the real child → PID/time → artifact → exit/cleanup → suite-reducer path while proving that harmless execution cannot create stability evidence or advancement.

The protocol and bridge must be designed so the later real CoreCycler completion/parser hook can emit the same schema using actual lifecycle evidence, without changing suite or state semantics.

## Task 1: Lock down the child-ownership contract before new runtime wiring

**Objective:** Define the behavior for every post-launch identity failure so a started child is never left unowned.

**Files:**
- Modify: `helpers/discovery-child-launch.psm1`
- Modify: `tests/DiscoveryChildExecutor.Tests.ps1`
- Create: `tests/DiscoveryChildOwnership.Tests.ps1`

**Step 1: Write failing tests for the new ownership envelope**

Add focused tests that assert:

```powershell
# A real process object with an unusable Id is cleaned before the adapter returns.
$result.Launched | Should Be $true
$result.Context | Should Be $null
$result.CleanupVerified | Should Be $true
$result.Reason | Should Be 'child_process_identity_unavailable'

# A valid PID with unreadable StartTime is also cleaned before return.
$result.ChildProcessId | Should Be 4242
$result.CleanupVerified | Should Be $true
$result.Reason | Should Be 'child_start_time_unavailable'
```

Use mocks for impossible OS observations and a temporary harmless child only for the success/timeout ownership case. Do not mock a successful cleanup as a substitute for proving the real temporary-child path exits.

**Step 2: Run the focused tests to verify RED**

Run:

```bash
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Import-Module Pester -MinimumVersion 3.4.0; Invoke-Pester -Script @{Path='tests\\DiscoveryChildExecutor.Tests.ps1'},@{Path='tests\\DiscoveryChildOwnership.Tests.ps1'}"
```

Expected: the new ownership assertions fail because the current adapter returns an unbound started child without bridge-owned cleanup.

**Step 3: Add one narrow owned-child cleanup helper**

Add a private helper in `helpers/discovery-child-launch.psm1` with a contract equivalent to:

```powershell
function Stop-DiscoveryOwnedChild {
    param(
        [Parameter(Mandatory=$true)] [System.Diagnostics.Process] $Process,
        [Parameter(Mandatory=$true)] [Int] $TimeoutMilliseconds
    )
    # Return @{ CleanupVerified = [bool]; Reason = [string] }
}
```

Rules:

- Operate only on the exact `Process` object returned by `Start-Process`.
- Use bounded wait/termination only for that owned child; never enumerate or kill processes by image name.
- Treat an inability to prove exit as `CleanupVerified = $false`.
- Dispose the process object after a verified final state where PowerShell object lifetime permits it.
- Do not use this helper for normal successful execution; it is compensation for a failed identity/binding path or a later timeout.

**Step 4: Extend the launch envelope minimally**

Keep the existing return fields and add only what the bridge needs:

```powershell
@{
    Launched        = [bool]
    Reason          = [string]
    ChildProcessId  = [int] or $null
    Context         = <context> or $null
    Process         = <owned process> or $null
    CleanupVerified = [bool] or $null
}
```

On launch failure, return `Launched = $false`. On post-launch PID/start-time/context failure, retain `Launched = $true`; perform owned cleanup before returning; never fabricate a PID or context. If cleanup cannot be proven, return a distinct hard reason such as `child_identity_unavailable_cleanup_unverified` and block the future bridge from creating any stage result.

**Step 5: Run GREEN and regressions**

Run the focused executor/ownership tests, then:

```bash
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Import-Module Pester -MinimumVersion 3.4.0; Invoke-Pester -Script @{Path='tests\\DiscoveryChildLaunchPlan.Tests.ps1'},@{Path='tests\\DiscoveryChildObservation.Tests.ps1'},@{Path='tests\\DiscoveryChildExecutor.Tests.ps1'},@{Path='tests\\DiscoveryChildOwnership.Tests.ps1'} -PassThru"
```

Expected: all pass; old readiness and observation behavior remains unchanged.

**Step 6: Review scope**

Inspect:

```bash
git diff -- helpers/discovery-child-launch.psm1 tests/DiscoveryChildExecutor.Tests.ps1 tests/DiscoveryChildOwnership.Tests.ps1
git -c core.whitespace=cr-at-eol diff --check
```

Do not commit without authorization.

## Task 2: Define a strict stage manifest and terminal-artifact schema

**Objective:** Create a durable, fresh, identity-bound protocol that a real child and a parent bridge can both validate.

**Files:**
- Create: `helpers/discovery-stage-protocol.psm1`
- Create: `tests/DiscoveryStageProtocol.Tests.ps1`
- Modify: `helpers/discovery-child-launch.psm1`
- Modify: `tests/DiscoveryChildLaunchPlan.Tests.ps1`

**Step 1: Write failing manifest/result validation tests**

Test creation and validation for:

- schema version;
- candidate/stage/workload/config fingerprint/log path identity;
- absolute manifest and result paths;
- fresh, absent result target;
- explicit declared expected-stress-process IDs (empty only for the harmless harness mode);
- distinct candidate/stage IDs;
- rejection of root `config.ini`, stale result files, changed config bytes, malformed JSON, and unknown fields/outcomes.

The test API should make intended values obvious:

```powershell
$manifest = New-DiscoveryStageManifest -Plan $plan -ResultPath $resultPath -Mode 'HARNESS_NO_WORKLOAD'
$decision = Test-DiscoveryStageManifest -ManifestPath $manifestPath -Plan $plan
$artifact = Read-DiscoveryStageTerminalArtifact -ResultPath $resultPath -Context $context
```

**Step 2: Run RED**

Run:

```bash
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Import-Module Pester -MinimumVersion 3.4.0; Invoke-Pester -Script @{Path='tests\\DiscoveryStageProtocol.Tests.ps1'}"
```

Expected: fail because protocol functions do not exist.

**Step 3: Implement the smallest protocol module**

Use a JSON manifest with one schema version and explicit fields. Do not place discovery identity in the root config file. The manifest should contain at least:

```json
{
  "schemaVersion": 1,
  "mode": "HARNESS_NO_WORKLOAD",
  "coreNumber": 2,
  "candidate": -18,
  "candidateAttemptId": "...",
  "stageAttemptId": "...",
  "workloadId": "...",
  "configPath": "...",
  "configFingerprint": "...",
  "logPath": "...",
  "resultPath": "...",
  "expectedStressProcessIds": []
}
```

The terminal artifact must repeat the identity and include a narrow protocol status. In harness mode, its only allowed status must be non-evidence, for example `HARNESS_NO_WORKLOAD_COMPLETE`; it must not contain `PASS`.

Write artifacts atomically: write a temporary sibling, parse/validate it, then rename to the fresh result path. Fail closed if the target exists or cannot be atomically promoted.

**Step 4: Extend the launch plan contract only as required**

Add an explicit manifest-path argument token to the plan rather than serializing metadata into command text. Update the fixed token contract from:

```text
powershell.exe -ExecutionPolicy Bypass -File <child> -ConfigPath <config>
```

to:

```text
powershell.exe -ExecutionPolicy Bypass -File <child> -ConfigPath <config> -DiscoveryStageManifestPath <manifest>
```

The manifest must be an absolute leaf path, distinct from config/log/result, and included in readiness validation. Preserve the existing no-manifest CoreCycler invocation behavior for legacy callers; the new token is only for the discovery launch plan.

**Step 5: Run GREEN and malformed-input regression tests**

Run the protocol and launch-plan test files. Confirm old plan tests are updated rather than weakened.

## Task 3: Add a non-hardware CoreCycler child protocol entry point

**Objective:** Make `script-corecycler.ps1` itself execute one harmless, explicit discovery-protocol child path and produce an actual bound terminal artifact before normal CoreCycler side effects.

**Files:**
- Modify: `script-corecycler.ps1`
- Modify: `helpers/discovery-stage-protocol.psm1`
- Create: `tests/DiscoveryCoreCyclerChildProtocol.Tests.ps1`
- Modify: `tests/DiscoveryStageConfigContract.Tests.ps1`

**Step 1: Write failing direct-child tests**

Use a temporary manifest/config/result path and invoke the actual `script-corecycler.ps1` process with:

```powershell
powershell.exe -ExecutionPolicy Bypass -File <repo>\script-corecycler.ps1 `
    -ConfigPath <temp-stage-config> `
    -DiscoveryStageManifestPath <temp-manifest>
```

Assert:

- the process exits normally;
- no normal CoreCycler log, stress-program process, CO tool, scheduler task, or `.automode` artifact is created;
- the terminal artifact is present, schema-valid, identity/config-fingerprint-bound, and marked only `HARNESS_NO_WORKLOAD_COMPLETE`;
- a changed config, malformed manifest, non-fresh result path, or root config path fails closed and writes no accepted artifact.

**Step 2: Run RED**

Run only `tests/DiscoveryCoreCyclerChildProtocol.Tests.ps1`; expect the parameter/protocol to be missing.

**Step 3: Add the opt-in parameter and early protocol branch**

At the existing parameter block in `script-corecycler.ps1`, add an optional `-DiscoveryStageManifestPath`. Before normal runtime initialization that reads hardware state, creates logs, starts stress programs, applies CO, or registers resume behavior:

1. detect a nonblank manifest argument;
2. import only `helpers/discovery-stage-protocol.psm1`;
3. validate the manifest against the explicit `-ConfigPath` and current config bytes;
4. write the harness terminal artifact atomically;
5. exit with a deterministic success/failure code.

Keep the legacy no-manifest path byte-for-byte behaviorally equivalent except for the existing Phase 2/3 changes. Do not overload `CoreFromAutoMode`.

**Step 4: Run GREEN and legacy config regressions**

Run:

```bash
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Import-Module Pester -MinimumVersion 3.4.0; Invoke-Pester -Script @{Path='tests\\DiscoveryCoreCyclerChildProtocol.Tests.ps1'},@{Path='tests\\DiscoveryStageConfigContract.Tests.ps1'} -PassThru"
```

Expected: harness path proves no normal workload side effects; explicit and default config contracts still pass.

**Step 5: Parser and diff review**

Parse `script-corecycler.ps1`, the new module, and tests with the PowerShell parser. Review only the added early branch and verify no code path can enter harness mode without explicit manifest input.

## Task 4: Build the owned child-to-terminal-result runtime bridge

**Objective:** Use a real harmless CoreCycler child, its observed identity, its artifact, and verified exit/cleanup to generate one suite-compatible non-evidence result.

**Files:**
- Create: `helpers/discovery-stage-runtime.psm1`
- Create: `tests/DiscoveryStageRuntimeBridge.Tests.ps1`
- Modify: `helpers/discovery-child-launch.psm1`
- Modify: `tests/DiscoveryChildOwnership.Tests.ps1`

**Step 1: Write failing bridge tests**

Test one end-to-end harmless bridge run using `script-corecycler.ps1` in manifest mode. Required assertions:

```powershell
$result.ChildExited | Should Be $true
$result.ExpectedStressProcessCleanupVerified | Should Be $true
$result.Outcome | Should Be 'INFRASTRUCTURE_INVALID'
$result.Context.childProcessId | Should BeGreaterThan 0
$result.Context.startedAt.Kind | Should Be ([DateTimeKind]::Utc)
$result.ArtifactStatus | Should Be 'HARNESS_NO_WORKLOAD_COMPLETE'
```

Also cover:

- child exit timeout → owned child cleanup attempted; no suite result if cleanup is unverified;
- nonzero child exit;
- missing, malformed, stale, or identity-mismatched terminal artifact;
- launch succeeds but PID/start time cannot bind → cleanup verified before return; no result accepted;
- declared expected stress PID that remains alive → cleanup verification false and no coordinator call;
- result/log/config replacement after plan construction → fail closed.

**Step 2: Run RED**

Run `tests/DiscoveryStageRuntimeBridge.Tests.ps1`; expect the runtime bridge function to be missing.

**Step 3: Implement one bounded bridge function**

Create an API such as:

```powershell
Invoke-DiscoveryStageRuntimeBridge \
  -Plan $plan \
  -ManifestPath $manifestPath \
  -TimeoutMilliseconds 10000
```

It must:

1. call the child-launch adapter;
2. require a bound PID and UTC context before considering an artifact;
3. wait only on the exact returned child process/PID with a bounded timeout;
4. on timeout or binding failure, compensate using the owned-child cleanup helper and return a hard bridge failure if exit cannot be proven;
5. after actual child exit, read and validate the terminal artifact against the context and manifest;
6. verify every declared expected stress-process ID has exited; for harness mode, verify the explicit empty set rather than inferring a broad system state;
7. map harness completion only to `INFRASTRUCTURE_INVALID`, never `PASS`;
8. return a strict result envelope containing context, outcome, `childExited`, actual Boolean `expectedStressProcessCleanupVerified`, and diagnostic reason.

Do not enumerate process names, parse arbitrary logs, or kill non-owned processes. Do not write discovery state in this task.

**Step 4: Run GREEN**

Run bridge, protocol, child launch, and observation tests together. Confirm the real harmless child run is the only real process execution and that it exits.

## Task 5: Connect the verified bridge result to the existing suite reducer

**Objective:** Prove that an actual bound harness result reaches the existing coordinator but cannot create false stability evidence.

**Files:**
- Modify: `helpers/discovery-stage-runtime.psm1`
- Modify: `tests/DiscoveryStageRuntimeBridge.Tests.ps1`
- Modify: `tests/DiscoverySuiteCoordinator.Tests.ps1`

**Step 1: Write failing integration tests**

Create a discovery state with `attemptStatus = 'APPLIED_VERIFIED'`, a matching workload/stage ID, and one completed-prefix position. Feed the bridge's real harness output directly to `Resolve-DiscoverySuiteStage`.

Assert:

```powershell
$decision.Accepted | Should Be $true
$decision.Disposition | Should Be 'RETRY_REQUIRES_FRESH_STAGE_IDENTITY'
$decision.State.currentCandidate | Should Be -18
$decision.State.lastObservedPass | Should Be $null
```

Also prove the same bridge output cannot be rewritten to `PASS` by a caller without failing artifact/result validation.

**Step 2: Run RED**

Run the runtime-bridge and suite-coordinator test files; expect absence of bridge-to-reducer wiring.

**Step 3: Implement the smallest adapter**

Add a function that accepts only the bridge envelope plus explicit suite state/progress inputs and delegates to `Resolve-DiscoverySuiteStage`. It must refuse to call the reducer when child exit or cleanup is not verified. It may not mutate scheduler state or persist discovery state itself.

**Step 4: Run GREEN and Phase 3 focused gate**

Run:

```bash
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Import-Module Pester -MinimumVersion 3.4.0; Invoke-Pester -Script @{Path='tests\\DiscoveryStageProtocol.Tests.ps1'},@{Path='tests\\DiscoveryCoreCyclerChildProtocol.Tests.ps1'},@{Path='tests\\DiscoveryStageRuntimeBridge.Tests.ps1'},@{Path='tests\\DiscoveryChildLaunchPlan.Tests.ps1'},@{Path='tests\\DiscoveryChildObservation.Tests.ps1'},@{Path='tests\\DiscoveryChildExecutor.Tests.ps1'},@{Path='tests\\DiscoveryChildOwnership.Tests.ps1'},@{Path='tests\\DiscoverySuiteCoordinator.Tests.ps1'} -PassThru"
```

Expected: all pass. The only end-to-end bridge outcome in this phase is non-evidence `INFRASTRUCTURE_INVALID`; no candidate advances and no hardware side effect occurs.

**Step 5: Phase 3 stop gate**

Stop Phase 3 after the following evidence exists:

- one actual `script-corecycler.ps1` harmless child is launched through the deterministic plan;
- PID/start time and terminal artifact are identity-bound;
- child exit and declared stress-process cleanup are verified;
- malformed, stale, timeout, identity-loss, and cleanup-loss paths fail closed;
- harness output reaches the existing suite reducer but cannot produce `OBSERVED_PASS`;
- no legacy ATM runtime behavior is changed outside explicit protocol invocation.

Do not add real workload parsing or broader coordination in Phase 3 unless the bridge exposes a concrete blocker.

## Task 6: Record the Phase 3 boundary and independently review it

**Objective:** Make the runtime-bridge evidence and remaining limits auditable before touching CO/scheduler paths.

**Files:**
- Modify: `PLAN.md`
- Modify: `ISSUES.md`
- Modify: `docs/wiki/README.md`
- Modify: `docs/wiki/architecture.md`
- Modify: `docs/wiki/diagrams/sequences.md`
- Modify: `docs/wiki/modules/discovery-child-launch.md`
- Modify: `docs/wiki/modules/discovery-suite-coordinator.md`
- Modify: `docs/wiki/modules/discovery-stage-evidence.md`

**Step 1: Update only factual current status**

Document:

- manifest/artifact schema and initial `HARNESS_NO_WORKLOAD_COMPLETE` meaning;
- bridge ownership/cleanup behavior;
- the exact condition that permits coordinator input;
- that no harmless artifact is stability evidence;
- remaining Phase 4 work: actual apply/readback, real workload terminal parser, opt-in scheduler, persistence of real transitions.

Do not claim Phase 3 hardware readiness or a real workload PASS.

**Step 2: Run documentation checks**

Verify Markdown links/fences, JSON state, and source-sha notes. Run `git -c core.whitespace=cr-at-eol diff --check`.

**Step 3: Independent review**

Use two reviews in order:

1. **Spec review:** verify the bridge meets every Phase 3 invariant, especially no synthetic PASS, no unowned child, and no runtime wiring beyond the explicit protocol.
2. **Quality/safety review:** inspect process ownership, manifest/result TOCTOU, atomic artifact writes, legacy impact, strict-mode behavior, and test isolation.

Resolve material findings with a new red-green regression before proceeding.

## Task 7: Characterize only the Phase 4 shared CO/apply/readback seams

**Objective:** Establish focused baseline behavior before adding opt-in candidate application.

**Files:**
- Create: `tests/DiscoveryPhase4Characterization.Tests.ps1`
- Potentially read only at first: `script-corecycler.ps1`
- Potentially modify later only if characterization exposes a narrow required seam.

**Step 1: Identify exact functions and data paths**

During execution, inspect the current implementations/callers of:

- `Set-NewVoltageValues` and the existing tested-core isolation-map construction;
- the concrete CO readback/effective-map capability, if any;
- legacy start-value initialization, including scalar `startValues = 0` compatibility (`I008`);
- `Test-AutomaticTestModeIncrease`, legacy PASS confirmation, error/reset, and resume-increase paths only if the new path would touch them.

**Step 2: Write focused baseline characterization tests**

The tests must capture current legacy outcomes without altering hardware:

- legacy ATM remains uphill-only after a pass/error;
- discovery-neutral start selection is not silently routed through a legacy negative-only scalar expansion;
- tested-core isolation-map construction does not reuse discovery candidate state;
- candidate application and effective-map readback are separable operations.

Use extracted/pure seams or controlled test doubles; do not execute Ryzen tools or write CO values.

**Step 3: Run characterization tests**

Expected: tests either establish a usable seam or expose one concrete blocker. If a blocker is found, document it in `ISSUES.md` and stop before inventing a broad workaround.

## Task 8: Implement a minimal opt-in one-core candidate policy shell

**Objective:** Create an isolated policy input that can select one candidate without changing legacy ATM scheduling or applying hardware state yet.

**Files:**
- Create: `helpers/discovery-phase4.psm1`
- Create: `tests/DiscoveryPhase4Policy.Tests.ps1`
- Modify: `helpers/discovery-state.psm1` only if a missing pure state transition is demonstrated.

**Step 1: Write failing policy tests**

Test a function shaped like:

```powershell
$decision = New-DiscoverySingleCandidateRequest \
  -State $state \
  -CoreNumber 2 \
  -Candidate -18
```

It must reject terminal/quarantined/retry-required state, candidate mismatch, unverified prior state, and non-single-core requests. It must not call `Set-NewVoltageValues`, `Start-Process`, scheduler code, or persistence.

**Step 2: Run RED, implement minimal pure policy, run GREEN**

Keep the policy module small and separate from legacy ATM. It should return only an explicit request/decision envelope needed by the next apply/readback adapter.

## Task 9: Add an effective-map-gated candidate apply/readback adapter

**Objective:** Reuse the smallest adequate existing CoreCycler CO mechanism for one core while ensuring intended values never count as evidence.

**Files:**
- Modify: `script-corecycler.ps1` only at the characterized seam, or extract a small helper under `helpers/` if that preserves legacy behavior more clearly.
- Modify: `helpers/discovery-phase4.psm1`
- Create: `tests/DiscoveryPhase4ApplyReadback.Tests.ps1`
- Modify: `tests/DiscoveryPhase4Characterization.Tests.ps1`

**Step 1: Write failing test doubles around the characterized shared seam**

Required outcomes:

- request selects only the target core candidate; non-tested cores receive the explicitly safe map;
- apply failure produces no `APPLIED_VERIFIED` state;
- mismatched or unavailable readback produces no stage launch request;
- successful exact readback transitions only that candidate attempt to `APPLIED_VERIFIED`;
- legacy ATM application path retains its existing values/status behavior.

**Step 2: Run RED**

Use controlled adapter doubles only. Do not invoke `ryzen-smu-cli`, PawnIO, or any actual hardware path.

**Step 3: Implement the narrow adapter**

Keep the code discovery-specific. Reuse CoreCycler's map-construction/application/readback primitive after characterization, but never call legacy confirmation/error transitions from discovery. Make the output explicit:

```powershell
@{
    AppliedVerified = [bool]
    Reason = [string]
    EffectiveMap = <normalized map or $null>
    State = <discovery state>
}
```

On apply/readback failure, retain pending/retry/quarantine semantics as evidence supports; never silently reapply a candidate associated with ambiguous disruption.

**Step 4: Run GREEN and affected legacy tests**

Run the new Phase 4 policy/apply/readback tests plus the exact legacy characterization tests established in Task 7.

## Task 10: Join one verified candidate to the Phase 3 bridge and durable transition

**Objective:** Prove the smallest non-hardware end-to-end control path for one core and one candidate.

**Files:**
- Modify: `helpers/discovery-phase4.psm1`
- Modify: `helpers/discovery-stage-runtime.psm1`
- Create: `tests/DiscoveryPhase4VerticalSlice.Tests.ps1`
- Modify: `tests/DiscoveryPersistenceContract.Tests.ps1`

**Step 1: Write one failing vertical-slice test**

Use adapter doubles for CO apply/readback and the harmless real CoreCycler child protocol for runtime process behavior. Assert the ordered flow:

```text
one core / one candidate
→ discovery policy request
→ apply/readback exact map
→ APPLIED_VERIFIED
→ stage manifest and child bridge
→ verified child exit + cleanup
→ suite receives non-evidence result
→ durable discovery state remains correct and does not advance
```

The first vertical slice must use the harness `INFRASTRUCTURE_INVALID` result, so it proves the control path and durable no-boundary behavior—not a fake PASS.

**Step 2: Run RED, implement only glue, run GREEN**

The glue may persist state through the existing atomic `.automode` mechanism only after it has a valid discovery transition. It must not invoke real CO or workload behavior during tests.

**Step 3: Add failure-path coverage**

Cover at minimum:

- apply/readback mismatch;
- child cannot bind PID/start time but cleanup succeeds;
- child cleanup cannot be proven;
- stale/malformed artifact;
- infrastructure-invalid result requires fresh stage identity and preserves candidate/boundary;
- interrupted applied candidate quarantines rather than reapplying.

## Task 11: Phase 4 slice review and stop gate

**Objective:** Verify the single-core/single-candidate vertical slice before any multi-core scheduling work.

**Files:**
- Modify only factual status/docs if all verification passes: `PLAN.md`, `ISSUES.md`, and relevant `docs/wiki/` pages.

**Verification commands:**

```bash
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Import-Module Pester -MinimumVersion 3.4.0; $result=Invoke-Pester -Script @{Path='tests'} -PassThru; Write-Output ('Passed=' + $result.PassedCount); Write-Output ('Failed=' + $result.FailedCount); if($result.FailedCount -ne 0){exit 1}"

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$paths=@('helpers\\discovery-state.psm1','helpers\\discovery-stage.psm1','helpers\\discovery-suite.psm1','helpers\\discovery-child-launch.psm1','helpers\\discovery-stage-protocol.psm1','helpers\\discovery-stage-runtime.psm1','helpers\\discovery-phase4.psm1','script-corecycler.ps1'); foreach($path in $paths){$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path),[ref]$tokens,[ref]$errors)|Out-Null;if($errors.Count){$errors;exit 1}}"

git -c core.whitespace=cr-at-eol diff --check
git diff --stat
git status --short
```

**Required independent reviews:**

1. Spec compliance: evidence gating, one-core scope, stale-result prevention, no fake PASS, persistence/recovery correctness, and no silent reapplication.
2. Code quality/safety: process ownership, cleanup, atomicity, strict typing, stale/TOCTOU boundaries, legacy impact, test isolation, and unnecessary divergence.

**Stop condition:** Do not generalize to synchronous rung progression until this one-core/one-candidate non-hardware path is independently reviewed and passes its full gate. If it exposes a shared-path defect, fix only the demonstrated defect with focused legacy characterization.

## Likely file set

### Create

- `helpers/discovery-stage-protocol.psm1`
- `helpers/discovery-stage-runtime.psm1`
- `helpers/discovery-phase4.psm1`
- `tests/DiscoveryChildOwnership.Tests.ps1`
- `tests/DiscoveryStageProtocol.Tests.ps1`
- `tests/DiscoveryCoreCyclerChildProtocol.Tests.ps1`
- `tests/DiscoveryStageRuntimeBridge.Tests.ps1`
- `tests/DiscoveryPhase4Characterization.Tests.ps1`
- `tests/DiscoveryPhase4Policy.Tests.ps1`
- `tests/DiscoveryPhase4ApplyReadback.Tests.ps1`
- `tests/DiscoveryPhase4VerticalSlice.Tests.ps1`

### Modify

- `helpers/discovery-child-launch.psm1`
- `helpers/discovery-state.psm1` only for a demonstrated missing transition
- `helpers/discovery-suite.psm1` only if a bridge exposes a concrete incompatible contract
- `script-corecycler.ps1` for an explicit, early, opt-in protocol path and later only the characterized discovery apply/readback seam
- `tests/DiscoveryChildLaunchPlan.Tests.ps1`
- `tests/DiscoveryChildObservation.Tests.ps1`
- `tests/DiscoveryChildExecutor.Tests.ps1`
- `tests/DiscoverySuiteCoordinator.Tests.ps1`
- `tests/DiscoveryStageConfigContract.Tests.ps1`
- `tests/DiscoveryPersistenceContract.Tests.ps1`
- `PLAN.md`, `ISSUES.md`, and affected `docs/wiki/` pages after verified milestones

## Risks and controls

| Risk | Control |
|---|---|
| A harmless child is mistaken for stability evidence | Harness protocol has no `PASS`; bridge maps it only to `INFRASTRUCTURE_INVALID`; suite test proves no advancement. |
| Child starts but PID/start time cannot bind | Exact process object remains owned; bounded compensating cleanup is required before return; unverified cleanup blocks result creation. |
| Stale manifest/result/log/config is accepted | Fresh result target, exact identity repetition, config fingerprints before and after context construction, atomic artifact promotion, and strict validation. |
| Broad process cleanup affects another workload | Operate only on the returned child process and explicit child-declared expected stress PIDs; never name-based enumeration/termination. |
| Legacy ATM behavior regresses | Explicit protocol branch is opt-in and early; Phase 4 changes only characterized shared seams with focused baseline tests. |
| Synthetic tests overclaim hardware behavior | Tests are described and asserted as non-hardware control-path evidence only; no real `PASS`, CO write, or stress program is used. |
| Phase 3 scope expands indefinitely | Stop after bridge-to-suite `INFRASTRUCTURE_INVALID` flow and its concrete failure cases pass. |

## Open questions to resolve during implementation, not by assumption

1. Which existing CoreCycler apply/readback primitive can provide an actual effective-map verification claim without duplicating or invoking hardware in tests?
2. Does the expected stress-process identity belong in a child-produced terminal artifact, an existing process metadata structure, or both? Choose the smallest source that can prove cleanup without broad process scans.
3. Does the explicit protocol path need a dedicated result directory outside `logs/`, or can a stage-unique path under the configured log root preserve the existing logging model without collision?
4. What is the smallest compatible neutral-start path for multi-core discovery (`I008`)? Resolve only before multi-core generalization; it is not required to close the one-core Phase 4 slice.
