# Automated Tuning Plan

## Overview

This fork should grow toward a guided, staged Ryzen Curve Optimizer tuning workflow while preserving CoreCycler's current manual/config-driven behavior. The automation should help users produce phase configs, run phases in order, parse results, and summarize candidate maps. It should not silently make riskier voltage choices.

The central safety rule is simple: automatic recovery after instability can only make a setting less aggressive. For Ryzen CO this means moving numeric values upward toward `0` unless the user explicitly opts into a positive limit. The default maximum must stay `0`.

Discovery and validation are separate. Isolated per-core discovery finds an edge. A candidate daily map applies margin. A validated final map passes combined, transition, alternate workload, and real-world checks.

## Phase Model

### 1. Baseline Sanity

Purpose: prove the machine is basically stable before undervolting is blamed for every failure.

Logic: run with neutral CO, memory and other overclocks in a known-good state, WHEA checks enabled, and no automatic CO movement. Any stress error, process failure, crash, or WHEA event should stop tuning until the baseline problem is resolved.

Recommended defaults:
- CO map: neutral, usually `0` for every core.
- Stress: Prime95 `Huge`/`SSE` or another high-boost light-load preset.
- Runtime: short to moderate, enough to catch obvious issues before discovery.
- WHEA: `lookForWheaErrors = 1`, `treatWheaWarningAsError = 1`.
- Automatic adjustment: disabled.

### 2. Sentinel Pass

Purpose: fail fast on cores likely to be weakest or most boost-sensitive.

Logic: test known weak cores, preferred cores, favored cores, or user-specified sentinel cores before spending time on the full CPU. The phase should support repeated entries in `coreTestOrder` so a sentinel can be tested more than once.

Recommended defaults:
- Core order: custom list of known weak or favored cores.
- Stress: Prime95 `Huge`/`SSE`.
- Runtime: short to moderate.
- WHEA: enabled and treated as instability.
- CO map: neutral for baseline sentinel, or current candidate map for later sentinel rechecks.

### 3. Coarse Isolated Discovery

Purpose: find a rough per-core edge quickly.

Logic: test one core at a time and keep non-tested cores neutral or safer. When an error, crash-resume event, or WHEA instability is attributed to the tested core, increase that core's CO value toward the configured maximum. Do not make values more negative during automatic recovery.

Recommended defaults:
- `setVoltageOnlyForTestedCore = 1`.
- `voltageValueForNotTestedCores = 0`.
- `maxValue = 0` unless explicit positive CO opt-in exists.
- `incrementBy`: larger than fine discovery, such as 2 to 5 points.
- Stress: Prime95 `Huge`/`SSE` for high-boost discovery.
- Resume: optional and clearly warned, because crash loops are possible.

### 4. Fine Isolated Discovery

Purpose: refine the rough edge without large jumps.

Logic: reseed from the coarse result and retest each core with `incrementBy = 1`. The phase should preserve per-core history so repeated instability can be summarized later.

Recommended defaults:
- `incrementBy = 1`.
- `maxValue = 0`.
- `setVoltageOnlyForTestedCore = 1`.
- Stress: same primary discovery stress as coarse discovery.
- Runtime: longer than coarse discovery.

### 5. Safety Margin

Purpose: turn an edge map into a candidate daily map.

Logic: apply a configurable per-core backoff after isolated discovery. The margin should make the CO map less aggressive, not more aggressive. For example, if the edge is `-23`, a 2 point margin produces `-21`.

Recommended defaults:
- Margin: 1 to 3 CO points, user configurable.
- Never cross above `0` unless positive CO has been explicitly allowed.
- Preserve both the edge map and the candidate daily map in logs and summaries.

### 6. Combined-Map Validation

Purpose: test all candidate CO values active together.

Logic: disable isolated-core neutralization and run with the candidate map active across all cores. Any error or WHEA means the candidate map needs more margin or per-core adjustment. Passing this phase does not prove final stability by itself.

Recommended defaults:
- `setVoltageOnlyForTestedCore = 0`.
- CO map: candidate daily map.
- Stress: Prime95 `Huge`/`SSE`, then optionally broader Prime95 presets.
- Runtime: longer than isolated discovery.
- Automatic adjustment: conservative. If enabled, only move values upward toward `0`.

### 7. Transition And Scheduler Validation

Purpose: catch instability that appears during core switches, load transients, and scheduler movement.

Logic: use `coreTestOrder = CorePairs`, `suspendPeriodically = 1`, and possibly `assignBothVirtualCoresForSingleThread = 1` where appropriate. This phase should run with the combined candidate map active.

Recommended defaults:
- Core order: `CorePairs`.
- Suspend/resume: enabled.
- Stress: Prime95 `Huge`/`SSE` first, then alternate modes if useful.
- WHEA: enabled and treated as instability.
- Automatic adjustment: disabled by default while validating a candidate map.

### 8. Alternate Workload Validation

Purpose: avoid overfitting to one stress tool.

Logic: validate the candidate map with y-cruncher and other supported tools. y-cruncher is useful for validation and for catching different failure modes, but it does not need to be the first-pass discovery tool.

Recommended defaults:
- y-cruncher mode: `auto` or a generation-appropriate binary.
- y-cruncher tests: start with focused sets such as `SFTv4`, `FFTv4`, and `N63`, then broaden as needed.
- Prime95 alternate modes: include AVX/AVX2/AVX512 only when appropriate for the CPU and cooling.
- Automatic adjustment: disabled or strictly less aggressive only.

### 9. Real-World Soak

Purpose: catch failures synthetic tests missed.

Logic: run the candidate map through normal workloads, games, idle time, sleep/wake, browser/video use, background tasks, and cold boots. WHEA events during soak should invalidate or at least downgrade confidence in the map.

Recommended defaults:
- Duration: user-defined, often multiple days of normal use.
- Logging: preserve WHEA and crash notes.
- Claim: use "candidate" until the user accepts the residual risk.

### 10. BIOS Finalization

Purpose: turn a validated temporary map into a deliberate persistent setting.

Logic: export a clear per-core map with zero-based CoreCycler numbering, warnings about BIOS numbering differences, and a reminder that SMU-applied values from CoreCycler are temporary. The tool should not silently write BIOS settings.

Recommended defaults:
- Export edge map, candidate daily map, and validated final map separately.
- Include CPU name, core count, phase history, WHEA count, stress tools, and date.
- Warn about Ryzen Master and BIOS numbering differences.

## Map Names

- Edge map: the least aggressive map that survived isolated discovery for each core. It is a tuning boundary, not a daily recommendation.
- Candidate daily map: the edge map after applying safety margin. This is the map used for combined and alternate validation.
- Validated final map: the candidate map after passing combined-map, transition, alternate workload, and real-world soak guidance. Even this is evidence of stability, not a guarantee.

## Likely Code Locations

- `script-corecycler.ps1`: current runtime and likely integration point.
- `Import-Settings` and `Get-Settings`: existing INI parsing and config merge behavior.
- `Initialize-AutomaticTestMode`: validates and applies starting CO/voltage values.
- `Get-CurveOptimizerValues`, `Set-CurveOptimizerValues`, and `Set-NewVoltageValues`: SMU read/write integration.
- `Test-AutomaticTestModeIncrease`: current less-aggressive automatic adjustment logic.
- `Test-StressTestProgrammIsRunning` and `Resolve-StressTestProgrammIsRunningError`: current stress error, WHEA, and adjustment decision path.
- `Get-LastWheaError`, `Compare-WheaErrorEntries`, `Convert-WheaMessageToApicId`, and `Convert-WheaMessageToCoreId`: WHEA detection and attribution.
- Main core-order construction in `script-corecycler.ps1`: current `Default`, `Alternate`, `Random`, `Sequential`, custom order, and `CorePairs` behavior.
- `Show-FinalSummary` and `Add-ToErrorCollection`: summary and error reporting.
- `helpers/CoreCyclerPhaseConfig.psm1`: offline phase schema defaults, ordering validation, guardrails, and CoreCycler INI generation.
- `ConvertFrom-CoreCyclerSummaryText` in `helpers/CoreCyclerPhaseConfig.psm1`: offline parser for final CO maps, WHEA counts, and per-core errors from summary/log text.
- `Get-CoreCyclerCandidateCurveOptimizerMap` in `helpers/CoreCyclerPhaseConfig.psm1`: offline safety-margin helper that turns parsed clean edge maps into candidate daily maps and rejects unstable summaries by default.
- `New-CoreCyclerCombinedMapValidationPhase` in `helpers/CoreCyclerPhaseConfig.psm1`: offline helper that turns a candidate daily map into a combined-map validation phase while keeping automatic adjustment disabled.
- `New-CoreCyclerTransitionValidationPhase` in `helpers/CoreCyclerPhaseConfig.psm1`: offline helper that turns a candidate daily map into a `CorePairs` transition validation phase while keeping automatic adjustment disabled.
- Ryzen generation profiles in `helpers/CoreCyclerPhaseConfig.psm1`: conservative opt-in defaults for Ryzen 5000, 7000, 8000, and 9000.
- `tests/phase-config-generator.Tests.ps1`: local tests for the offline generator.
- `tests/combined-map-validation.Tests.ps1`: local tests for candidate-map validation config generation and positive CO guardrails.
- `tests/transition-validation.Tests.ps1`: local tests for `CorePairs` transition validation config generation and positive CO guardrails.
- `tests/summary-parser.Tests.ps1`: local tests for summary/log parsing.
- `tests/safety-margin.Tests.ps1`: local tests for candidate daily map guardrails.
- `tests/fixtures/`: generated INI snapshots for representative profile-backed phases.
- `configs/`: existing example config location. Future generated configs should remain easy to compare with these examples.
- `docs/`: planning, safety, and user workflow documentation.

For upstream compatibility, future work should prefer adding pure helpers and optional phase/config generation before wiring new behavior into the main loop.

## Risks And Mitigations

- Positive CO risk: default `maxValue` must remain `0`; positive values require explicit opt-in and prominent warnings.
- Crash loop risk: crash-resume and Scheduled Task creation must be explicit, logged, and easy to disable.
- False stability claims: docs and summaries must say isolated per-core testing is discovery only.
- WHEA undercounting or misattribution: treat WHEA as instability even when APIC mapping is uncertain; surface uncertainty in summaries.
- Overfitting to one workload: keep alternate workload validation as a separate required confidence step.
- Hardware generation differences: add Ryzen generation profiles conservatively and allow user override.
- Config generation mistakes: validate schema, core counts, map lengths, CO bounds, and phase ordering before writing runnable configs.
- Upstream merge friction: keep default behavior unchanged and keep new staged workflow optional.

## Validation Strategy

The current fork has a dependency-free PowerShell test harness for offline helper code in `tests/run-tests.ps1`. Future code should make phase schema validation, config generation, summary parsing, and guardrail logic pure enough to test without launching stress tools or touching SMU. Stress execution tests should remain manual or clearly marked hardware-integration checks.
