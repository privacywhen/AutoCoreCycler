# Module: Persistence and recovery

## Purpose

Existing ATM persists enough state to resume after an unexpected exit and separately appends legacy results. It uses two `.automode` generations plus a permanent results file. Discovery now adds an optional isolated snapshot field without copying legacy crash-attribution policy.

## Durable artifacts

| Artifact | Role |
|---|---|
| `.automode` | Current JSON recovery state, optionally containing `discoveryStates`. |
| `.automode-bak` | Previous valid state generation. |
| `.automode-temp` | Temporary generation parsed before replacement. |
| `*_automode-results.txt` | Append-only legacy ATM results. |
| `\\CoreCycler\\CoreCycler AutoMode Startup Task` | Scheduled legacy recovery task. |

## Legacy flow

`Save-AutoModeState` writes JSON to `.automode-temp`, parses it back, rotates current state to backup, then replaces it. `Get-AutoModeFileContent` tries current state then backup. On resume, `Initialize-AutomaticTestMode` restores state and merges terminal results to avoid retesting a terminal legacy core after a torn state save. [`helpers/automode-startup-script.ps1`](../../../helpers/automode-startup-script.ps1) validates state age/fields, waits if configured, and restarts the batch launcher with the stored core.

## Discovery snapshot flow

When discovery state exists, `Save-AutoModeState` adds `ConvertTo-DiscoveryStateSnapshot` output under `discoveryStates`; when discovery is unused, it does not add that field, preserving the legacy document shape. Recovery calls `Restore-DiscoveryStateSnapshot` and rejects the complete document if the discovery snapshot is malformed, stale, torn, inconsistent, missing an expected core, or contains an unexpected core. No partial discovery subset is returned.

The discovery snapshot is schema version 2 and requires `attemptStatus`. Candidate/stage attempt identities remain separate from legacy `$coreStates`, and retry identities must be fresh across the prior candidate and stage IDs.

## Boundary

The persistence contract is implemented and tested, but discovery scheduling, candidate application, workload execution, and specialized resume/quarantine orchestration are not wired into production. Existing legacy recovery behavior remains the active runtime path.
