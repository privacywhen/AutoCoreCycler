# Module: Discovery stage evidence

## Purpose and status

[`helpers/discovery-stage.psm1`](../../../helpers/discovery-stage.psm1) defines the identity contract for one workload stage. It is a pure Phase 3 foundation: it validates evidence but does not launch a process, parse a workload log, apply CO, or perform cleanup.

## Public API

| Function | Behavior |
|---|---|
| `Get-DiscoveryStageConfigFingerprint` | Reads exact config bytes and returns a lowercase SHA-256 fingerprint. |
| `New-DiscoveryStageContext` | Creates a context binding core, candidate, candidate/stage IDs, workload, config path/fingerprint, log path, child PID, and UTC start time. |
| `Test-DiscoveryStageResult` | Accepts only narrow terminal outcomes whose identity, config, log, process, and start time match the active context. |

## Identity contract

A stage context contains:

- physical core number and candidate CO value;
- candidate-attempt and stage-attempt IDs;
- workload ID;
- resolved stage-config path and exact-byte fingerprint;
- stage-unique log path;
- positive child process ID;
- UTC child start time.

The candidate and stage IDs must be distinct. Config fingerprints are recomputed when evidence is validated, so config drift or an unavailable config fails closed. A stage log must exist for terminal evidence, but the child observation adapter intentionally allows the log to appear after the launch boundary.

## Accepted terminal outcomes

`Test-DiscoveryStageResult` accepts only:

- `PASS`;
- `ATTRIBUTED_FAIL`;
- `AMBIGUOUS_FAIL`;
- `INFRASTRUCTURE_INVALID`.

Missing or stale candidate/stage identity, mismatched workload/core/candidate, changed config bytes, missing or mismatched log, PID, or start time is rejected before classification.

## Tests

[`tests/DiscoveryStageEvidence.Tests.ps1`](../../../tests/DiscoveryStageEvidence.Tests.ps1) covers valid identity, stale attempts, config mutation/deletion, missing core/candidate values, missing process/time identity, and invalid outcomes. The child observation contract in [`tests/DiscoveryChildObservation.Tests.ps1`](../../../tests/DiscoveryChildObservation.Tests.ps1) additionally covers explicit UTC identity and the post-context fingerprint recheck.
