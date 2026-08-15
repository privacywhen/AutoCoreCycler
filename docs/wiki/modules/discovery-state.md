# Module: Discovery state (Phase 1)

## Status

[`helpers/discovery-state.psm1`](../../../helpers/discovery-state.psm1) and [`tests/DiscoveryState.Tests.ps1`](../../../tests/DiscoveryState.Tests.ps1) are **untracked working-tree files** in this snapshot. They implement a pure in-memory fragment of the proposed state machine. The main script does not import them, so they do not change production launch, CO application, workloads, or recovery.

## Public API

| Function | Behavior |
|---|---|
| `New-DiscoveryCoreState` | Creates state for a core, current candidate, platform minimum, candidate identity, and stage identities. |
| `Resolve-DiscoveryEvidence` | Validates evidence and returns `{ Accepted, Reason, State }`. |
| `Test-DiscoveryCoreCanBeScheduled` | Returns false for terminal discovery resolutions. |

## Implemented transitions

```mermaid
stateDiagram-v2
    [*] --> Active
    Active --> Active: verified complete OBSERVED_PASS
last pass; candidate = candidate - 1
    Active --> PlatformLimit: pass at platform minimum
    Active --> Candidate: ATTRIBUTED_FAIL after prior pass
    Active --> NoBaseline: ATTRIBUTED_FAIL before prior pass
    Active --> Quarantined: AMBIGUOUS_FAIL
    Active --> Active: INFRASTRUCTURE_INVALID
no boundary movement
```

Evidence requires verified application; matching candidate value, candidate attempt, and stage attempts; and `CompleteSuite` for observed pass. Attributed failure records the failing candidate and resolves to the prior complete-suite pass when present.

## Current discrepancy

The test file expects `New-DiscoveryCoreState` to reject candidate/stage ID collisions and duplicate stage IDs. The module snapshot does not contain those uniqueness checks. This is an unverified working-tree mismatch that must be resolved before Phase 1 completion can be claimed.
