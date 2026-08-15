# AutoCoreCycler Code Wiki

AutoCoreCycler is a Windows PowerShell repository based on CoreCycler. Its development goal is an **opt-in descending per-core Ryzen Curve Optimizer (CO) discovery mode**: test one physical core at a time, verify the effective CO map, require a complete workload suite for a passing candidate, then advance exactly one CO unit more negative.

The repository reuses CoreCycler's stress execution, CPU affinity, WHEA parsing, Automatic Test Mode (ATM), persistence, and recovery mechanisms. Discovery is intended to be a localized policy extension so upstream CoreCycler changes remain practical to merge.

> **Snapshot boundary:** source commit `613dc65c78ebab8285ca81e2def6ac5ceb2959dd` (`AI Scaffolding`). The working tree also contains uncommitted Phase 1 discovery-state scaffolding in `helpers/discovery-state.psm1` and `tests/DiscoveryState.Tests.ps1`; it is not wired into the production path.

## Key concepts

- **Candidate attempt** — one core at one CO value across the required suite.
- **Stage attempt** — one workload execution inside a candidate attempt, with a fresh evidence boundary.
- **Observed pass** — complete-suite evidence after verified application; it is not permanent-stability proof.
- **Attributed failure** — positive evidence tied to the active core; it can establish a discovery boundary.
- **Ambiguous/infrastructure-invalid evidence** — does not establish a CPU boundary.

## Entry points

- [`Run CoreCycler.bat`](../../Run%20CoreCycler.bat) — normal launcher.
- [`Run Multiconfig CoreCycler.bat`](../../Run%20Multiconfig%20CoreCycler.bat) — multi-configuration launcher.
- [`script-corecycler.ps1`](../../script-corecycler.ps1) — main implementation.
- [`helpers/automode-startup-script.ps1`](../../helpers/automode-startup-script.ps1) — scheduled-task recovery helper.
- [`helpers/discovery-state.psm1`](../../helpers/discovery-state.psm1) — current untracked pure Phase 1 helpers.

## Module map

| Module | Purpose |
|---|---|
| [Main orchestrator](modules/main-orchestrator.md) | Startup, settings, lifecycle, and integration point. |
| [Automatic Test Mode](modules/automatic-test-mode.md) | Existing per-core adjustment and final-value behavior. |
| [Persistence and recovery](modules/persistence-and-recovery.md) | `.automode`, results, resume state, and recovery. |
| [Stress-test adapters](modules/stress-test-adapters.md) | Prime95, y-cruncher, AIDA64, and Linpack lifecycle. |
| [Affinity and WHEA](modules/affinity-and-whea.md) | Core mapping, thread affinity, and WHEA attribution. |
| [Discovery state (Phase 1)](modules/discovery-state.md) | Unintegrated pure transition helpers. |
| [Configuration profiles](modules/configuration-profiles.md) | INI settings and supplied profiles. |
| [Administrative helpers](modules/administrative-helpers.md) | Event Log and automatic-resume helpers. |

- [Architecture](architecture.md)
- [Getting started](getting-started.md)
- [Sequence diagrams](diagrams/sequences.md)

## Maintenance

Treat source, tests, `GOAL.md`, `DESIGN.md`, `DECISIONS.md`, `PLAN.md`, and `ISSUES.md` as authoritative. Update the affected module or diagram when entry points, persisted schema, evidence semantics, public configuration, or workflow changes. Do not document planned behavior as production behavior until it is integrated and passes its phase gate.
