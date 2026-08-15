# Module: Stress-test adapters

## Purpose

The main script wraps multiple stress programs behind a shared lifecycle so scheduling and legacy ATM avoid duplicating high-level control.

| Program | Initialize | Start | Close |
|---|---|---|---|
| Prime95 | `Initialize-Prime95` | `Start-Prime95` | `Close-Prime95` |
| y-cruncher | `Initialize-yCruncher` | `Start-yCruncher` | `Close-yCruncher` |
| AIDA64 | `Initialize-Aida64` | `Start-Aida64` | `Close-Aida64` |
| Linpack | `Initialize-Linpack` | `Start-Linpack` | `Close-Linpack` |

Generic entrypoints are `Initialize-StressTestProgram`, `Start-StressTestProgram`, and `Close-StressTestProgram` in [`script-corecycler.ps1`](../../../script-corecycler.ps1). `Get-NewLogfileEntries` incrementally reads stress logs and resets its positions if a log is recreated or truncated.

## Discovery relationship

The Phase 3 feasibility decision is a hybrid model: each workload stage will run as a fresh CoreCycler child invocation rather than switching adapters in one process. CoreCycler selects startup-global configuration and adapter state, rewrites program-global configuration, and retains parser/process metadata; in-process switching would require invasive reset logic and risk stale evidence.

The pure suite reducer currently validates ordered stage results and lifecycle facts but does not call these adapters. The isolated child-launch tests use only a harmless temporary script, not Prime95, y-cruncher, AIDA64, Linpack, or a real CoreCycler child.

The design suite is y-cruncher Kagari, Prime95 SSE Huge FFT, Prime95 AVX2 720K/768K, and Prime95 AVX2 1344K. A candidate passes only after every stage passes after application verification; runtime stage wiring and parser integration remain future work.
