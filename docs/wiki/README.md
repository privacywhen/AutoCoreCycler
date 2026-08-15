# AutoCoreCycler Code Wiki

AutoCoreCycler is a Windows PowerShell repository based on CoreCycler. Its development goal is an **opt-in descending per-core Ryzen Curve Optimizer (CO) discovery mode**: test one physical core at a time, verify the effective CO map, require a complete workload suite for a passing candidate, then advance exactly one CO unit more negative.

The repository reuses CoreCycler's stress execution, CPU affinity, WHEA parsing, Automatic Test Mode (ATM), persistence, and recovery mechanisms. Discovery remains a separate policy and evidence layer; legacy uphill ATM semantics are not made direction-neutral.

> **Snapshot boundary:** committed source HEAD is `a266f9e6bbe0e03c5fe912f97100d86a313d6207` (`Summary: feat(discovery): add hybrid stage coordination foundation`). The current worktree also contains the uncommitted Phase 3 launch-adapter seam in `helpers/discovery-child-launch.psm1` and `tests/DiscoveryChildExecutor.Tests.ps1`, plus the related status-document edits. This wiki refresh documents that current worktree boundary; the Phase 3 seam is not wired into production CoreCycler execution.

## Key concepts

- **Candidate attempt** — one physical core at one CO value across the required workload suite.
- **Stage attempt** — one workload execution inside a candidate attempt, with a fresh evidence boundary.
- **Stage context** — candidate/stage/workload identity bound to the core, candidate, config fingerprint, log path, child PID, and UTC start time.
- **Observed pass** — complete-suite evidence after verified application; it is not permanent-stability proof.
- **Attributed failure** — positive evidence tied to the active core; it can establish a discovery boundary.
- **Ambiguous/infrastructure-invalid evidence** — does not establish a CPU boundary.
- **Fresh-child stage execution** — Phase 3's chosen hybrid design: each workload stage gets a separate child because CoreCycler configuration, adapters, parsers, and process metadata are startup-global.

## Implementation status

- **Phase 1:** pure discovery transition/evidence semantics are implemented and tested.
- **Phase 2:** optional durable discovery snapshots, schema validation, interruption handling, and fresh retry identities are implemented without changing legacy ATM state when discovery is unused.
- **Phase 3 foundation:** stage config/evidence contracts, ordered synthetic suite reduction, deterministic child plans, just-before-launch readiness, externally observed identity binding, and an isolated plan-to-child launch adapter are implemented and tested.
- **Not integrated:** the Phase 3 helpers are not wired to the discovery coordinator, CoreCycler result parsing, CO application, scheduler/resume flow, UAC/elevation, or hardware testing. The adapter's tests use only a harmless temporary child script.

## Entry points

- [`Run CoreCycler.bat`](../../Run%20CoreCycler.bat) — normal launcher.
- [`Run Multiconfig CoreCycler.bat`](../../Run%20Multiconfig%20CoreCycler.bat) — multi-configuration launcher.
- [`script-corecycler.ps1`](../../script-corecycler.ps1) — main implementation, including optional `-ConfigPath` input and optional discovery snapshot persistence.
- [`helpers/automode-startup-script.ps1`](../../helpers/automode-startup-script.ps1) — scheduled-task recovery helper.
- [`helpers/discovery-state.psm1`](../../helpers/discovery-state.psm1) — pure discovery state, evidence, persistence, recovery, and retry contracts.
- [`helpers/discovery-stage.psm1`](../../helpers/discovery-stage.psm1) — config fingerprints, stage contexts, and stage-result identity validation.
- [`helpers/discovery-suite.psm1`](../../helpers/discovery-suite.psm1) — ordered workload-suite reducer.
- [`helpers/discovery-child-launch.psm1`](../../helpers/discovery-child-launch.psm1) — deterministic child plan, readiness, observation binding, and isolated launch seam.

## Module map

| Module | Purpose |
|---|---|
| [Main orchestrator](modules/main-orchestrator.md) | Startup, settings, legacy lifecycle, optional discovery persistence, and integration boundary. |
| [Automatic Test Mode](modules/automatic-test-mode.md) | Existing uphill per-core adjustment and final-value behavior. |
| [Persistence and recovery](modules/persistence-and-recovery.md) | Legacy `.automode` durability plus optional discovery snapshot recovery. |
| [Stress-test adapters](modules/stress-test-adapters.md) | Prime95, y-cruncher, AIDA64, and Linpack lifecycle reused by future stages. |
| [Affinity and WHEA](modules/affinity-and-whea.md) | Core mapping, thread affinity, and WHEA attribution. |
| [Discovery state](modules/discovery-state.md) | Candidate transitions, evidence classes, schema v2 snapshots, interruption recovery, and retry identity. |
| [Discovery stage evidence](modules/discovery-stage-evidence.md) | Config-byte fingerprints, stage contexts, and narrow terminal-result validation. |
| [Discovery suite coordinator](modules/discovery-suite-coordinator.md) | Pure ordered multi-workload reducer and lifecycle gate. |
| [Child launch boundary](modules/discovery-child-launch.md) | Deterministic plan, readiness, observed identity, and isolated plan-to-child launch seam. |
| [Configuration profiles](modules/configuration-profiles.md) | INI settings, explicit stage config input, and supplied profiles. |
| [Administrative helpers](modules/administrative-helpers.md) | Event Log and automatic-resume helpers. |

- [Architecture](architecture.md)
- [Getting started](getting-started.md)
- [Sequence diagrams](diagrams/sequences.md)

## Maintenance

Treat source, tests, `GOAL.md`, `DESIGN.md`, `DECISIONS.md`, `PLAN.md`, and `ISSUES.md` as authoritative. Update the affected module or diagram when entry points, persisted schema, evidence semantics, public configuration, or workflow changes. Keep planned runtime behavior clearly separate from the implemented pure/synthetic boundaries until the relevant phase gate is complete.
