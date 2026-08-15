# Module: Discovery child launch boundary

## Purpose and status

[`helpers/discovery-child-launch.psm1`](../../../helpers/discovery-child-launch.psm1) contains the narrow Phase 3 boundary between a deterministic stage plan and a future coordinator. It is deliberately isolated from [`script-corecycler.ps1`](../../../script-corecycler.ps1), the suite reducer, workload parsing, CO application, scheduler/resume behavior, UAC/elevation, and hardware operations.

## Public API

| Function | Behavior |
|---|---|
| `New-DiscoveryStageChildLaunchPlan` | Validates stage inputs, rejects the repository root `config.ini` and occupied log targets, fingerprints config bytes, and returns a fixed PowerShell invocation plus identity template. |
| `Test-DiscoveryStageChildLaunchPlanReadiness` | Revalidates plan structure, child script/config availability, root-config prohibition, config fingerprint, and fresh log target immediately before launch. |
| `New-DiscoveryStageContextFromObservedChild` | Accepts only caller-supplied positive exact `[Int]` PID and explicit UTC `[DateTime]`, then binds them through the existing stage-context contract with final plan/config identity checks. |
| `Start-DiscoveryStageChildFromPlan` | Calls readiness, starts only the plan's exact tokenized invocation, separates launch/PID/start-time failure ownership, and returns a decision envelope. |

## Exact launch contract

The plan uses:

```text
powershell.exe -ExecutionPolicy Bypass -File <child-script> -ConfigPath <stage-config>
```

The config path is a separate argument token, the working directory is derived from the child script, `-CoreFromAutoMode` is not added, and the stage config must not be the repository `config.ini`. The log target must be absent before readiness succeeds.

## Decision envelopes

- Readiness failure: `Launched = $false`, no PID, no context.
- `Start-Process` failure: `Launched = $false`, no PID, no context.
- Confirmed launch with unavailable PID: `Launched = $true`, no fabricated PID/context.
- Confirmed launch with unavailable start time: `Launched = $true`, acquired PID retained, no context.
- Confirmed launch with observation/config rejection: `Launched = $true`, acquired PID retained, no context.
- Successful observation: `Launched = $true`, PID retained, fingerprint-bound stage context returned.

This ownership distinction leaves a post-launch child identifiable for the later caller/coordinator cleanup boundary without pretending that it never started.

## Current safety boundary

The adapter does not enumerate or stop processes and does not perform cleanup itself. It uses only plan-provided `FilePath`, `ArgumentList`, and `WorkingDirectory` after readiness. Config drift is checked again by the observation/context contract. Child-script and log-path replacement between readiness and `Start-Process` remain a later integration-boundary concern.

## Tests

[`tests/DiscoveryChildLaunchPlan.Tests.ps1`](../../../tests/DiscoveryChildLaunchPlan.Tests.ps1) covers plan construction and readiness. [`tests/DiscoveryChildObservation.Tests.ps1`](../../../tests/DiscoveryChildObservation.Tests.ps1) covers external identity binding and config TOCTOU protection. [`tests/DiscoveryChildExecutor.Tests.ps1`](../../../tests/DiscoveryChildExecutor.Tests.ps1) covers harmless synthetic launch, launch failure, PID/start-time ownership failures, and config-drift no-launch behavior. The executor test is the only current repository call site for `Start-DiscoveryStageChildFromPlan` outside its definition.
