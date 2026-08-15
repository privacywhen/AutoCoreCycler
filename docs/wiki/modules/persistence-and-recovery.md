# Module: Persistence and recovery

## Purpose

Existing ATM persists enough state to resume after an unexpected exit and separately appends legacy results. It uses two `.automode` generations plus a permanent results file. Discovery must reuse this durability substrate without copying its crash-attribution policy.

## Durable artifacts

| Artifact | Role |
|---|---|
| `.automode` | Current JSON recovery state. |
| `.automode-bak` | Previous valid state generation. |
| `.automode-temp` | Temporary generation parsed before replacement. |
| `*_automode-results.txt` | Append-only legacy ATM results. |
| `\CoreCycler\CoreCycler AutoMode Startup Task` | Scheduled recovery task. |

## Flow

`Save-AutoModeState` writes JSON to `.automode-temp`, parses it back, rotates current state to backup, then replaces it. `Get-AutoModeFileContent` tries current state then backup. On resume, `Initialize-AutomaticTestMode` restores state and merges terminal results to avoid retesting a terminal legacy core after a torn state save. [`helpers/automode-startup-script.ps1`](../../../helpers/automode-startup-script.ps1) validates state age/fields, waits if configured, and restarts the batch launcher with the stored core.

## Discovery requirement

Current resume assumes the active core may have crashed and increases its value before reapplication. Discovery requires durable candidate/workload identity, verified-application state, stage identity/results, and retry versus quarantine classification. Phase 1 does not persist state; persistence is planned for Phase 2.
