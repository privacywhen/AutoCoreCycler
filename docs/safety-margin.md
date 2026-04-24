# Safety Margin Recommendations

`Get-CoreCyclerCandidateCurveOptimizerMap` in `helpers/CoreCyclerPhaseConfig.psm1` consumes parsed summary output from `ConvertFrom-CoreCyclerSummaryText` and recommends a candidate daily Curve Optimizer map.

The helper is offline and side-effect-free. It does not run CoreCycler, touch SMU, query hardware, or write BIOS settings.

## Behavior

- Reads `CurveOptimizer.FinalValues` from a parsed summary as the edge map.
- Adds a non-negative `SafetyMargin` to each CO value.
- Because CO values become less aggressive as they move upward, this can only recommend values that are equal to or safer than the edge map.
- Clamps recommendations at `0` by default.
- Rejects positive output unless `-AllowPositiveCurveOptimizer` is passed explicitly.
- A positive `-MaximumValue` is also rejected unless positive CO is explicitly allowed.
- Rejects parsed summaries that contain core errors, error details, or WHEA counts by default.
- `-AllowUnstableSummary` exists only for diagnostic workflows; do not use it to produce candidate daily maps.

## Example

```powershell
Import-Module .\helpers\CoreCyclerPhaseConfig.psm1 -Force

$text = Get-Content .\tests\fixtures\final-summary-adjusted-clean.log -Raw
$summary = ConvertFrom-CoreCyclerSummaryText -Text $text

$recommendation = Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summary -SafetyMargin 2
$recommendation.EdgeMap
$recommendation.CandidateMap

$combinedPhase = New-CoreCyclerCombinedMapValidationPhase -Name 'combined-map-validation' -CandidateMap $recommendation
$transitionPhase = New-CoreCyclerTransitionValidationPhase -Name 'transition-validation' -CandidateMap $recommendation
```

An edge map of `-20, -17, -15, -28` with a safety margin of `2` becomes a candidate daily map of `-18, -15, -13, -26`.

## Important

A candidate daily map is not a validated final map. It still needs combined-map validation, transition validation, alternate workload validation, and real-world soak before the user should consider applying it permanently in BIOS or startup tooling.

Combined-map and transition validation configs generated from candidate maps keep automatic adjustment disabled. In the current runtime, that means the generated config records the candidate map and validation settings, but does not apply the map by itself.

If a summary still reports Prime95 calculation errors, WHEA, or any per-core errors, treat it as a failed tuning phase. Resolve the instability and retest before producing a candidate daily map.
