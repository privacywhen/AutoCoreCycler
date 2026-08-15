# Module: Discovery suite coordinator

## Purpose and status

[`helpers/discovery-suite.psm1`](../../../helpers/discovery-suite.psm1) is a pure ordered reducer for the required multi-workload candidate suite. It is not imported by the production scheduler; it exists to establish the Phase 3 coordinator contract before runtime wiring.

## Public API

| Function | Behavior |
|---|---|
| `Resolve-DiscoverySuiteStage` | Validates current index, completed-prefix order, application status, stage context/result identity, child lifecycle facts, and terminal outcome; returns a decision envelope with next stage/state. |

Internal helpers validate the required workload set and copy state without aliasing stage-attempt metadata.

## Progression rules

1. The completed workload list must be an exact prefix of the required ordered workload list.
2. `attemptStatus` must be `APPLIED_VERIFIED` before evidence can count.
3. The stage context must match the current core, candidate, candidate-attempt ID, workload, and expected stage-attempt ID.
4. `childExited` and `expectedStressProcessCleanupVerified` must both be actual Boolean `$true` values; coercible strings or integers are rejected.
5. A non-final `PASS` advances exactly one workload index.
6. Only the final ordered `PASS` creates complete-suite `OBSERVED_PASS` evidence for the discovery state reducer.
7. `ATTRIBUTED_FAIL` fails fast; `AMBIGUOUS_FAIL` quarantines; `INFRASTRUCTURE_INVALID` preserves the CPU boundary and requires a fresh stage identity for retry.
8. Missing, stale, out-of-order, or lifecycle-unverified evidence leaves suite progress unchanged.

## Design boundary

The reducer intentionally does not start CoreCycler, parse logs, inspect Windows processes, apply CO, or manage scheduler/UAC/hardware behavior. The chosen future architecture is one fresh CoreCycler child per workload stage because CoreCycler workload configuration, adapter state, parser state, and process metadata are startup-global.

## Tests

[`tests/DiscoverySuiteCoordinator.Tests.ps1`](../../../tests/DiscoverySuiteCoordinator.Tests.ps1) covers out-of-order stages, lifecycle coercion, missing cleanup, infrastructure-invalid and ambiguous outcomes, attributable failure, non-final advancement, and final ordered pass conversion.
