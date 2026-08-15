# Module: Automatic Test Mode

## Purpose

Automatic Test Mode (ATM) is the existing CoreCycler subsystem for per-core CO or voltage-offset adjustment during repeated stress tests. It is the substrate for discovery, but legacy behavior must remain unchanged outside opt-in discovery.

## Key source locations

- [`Test-CoreIsResolved`](../../../script-corecycler.ps1#L4793) — treats `confirmed`, `unstable`, and `ignored` as terminal.
- [`Initialize-CoreStates`](../../../script-corecycler.ps1#L4893) — initializes/reconciles legacy state.
- [`Set-CoreState`](../../../script-corecycler.ps1#L5227) — changes state and terminal behavior.
- [`Test-AutomaticTestModeIncrease`](../../../script-corecycler.ps1#L11750) — moves a failing value toward `maxValue`, persists, then applies it.

## Legacy state

Existing state has fields equivalent to `status`, `value`, `passes`, `errors`, `tests`, `source`, `reason`, and `updatedAt`. `confirmed` means enough legacy consecutive passes; `unstable` means it could not be stabilized before the upper limit; `ignored` is configuration exclusion.

`knownGoodValues` prepopulates legacy confirmed values for Ryzen. It must not represent isolated discovery candidates, which are weaker evidence.

## Discovery compatibility

Discovery needs separate state: current candidate, last observed pass, first observed fail, candidate/stage identity, stage results, and discovery resolution. It advances exactly `-1` after a verified complete-suite pass rather than using legacy generic error adjustment.
