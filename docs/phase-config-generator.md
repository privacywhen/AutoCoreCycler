# Phase Config Generator

`helpers/CoreCyclerPhaseConfig.psm1` contains an offline schema helper and INI generator for staged CoreCycler tuning phases. It does not execute CoreCycler, launch stress tools, require admin rights, or touch SMU/Curve Optimizer values.

## Supported Phase Types

- `BaselineSanity`
- `Sentinel`
- `CoarseIsolatedDiscovery`
- `FineIsolatedDiscovery`
- `CombinedMapValidation`
- `TransitionValidation`
- `AlternateWorkloadValidation`

The generator validates phase ordering with `Test-CoreCyclerPhaseSequence`. Discovery phases must not appear after later validation phases.

## Ryzen Generation Profiles

Profiles are opt-in. They add generation-aware defaults and bounds without executing anything:

- `Ryzen5000`: minimum CO `-30`, y-cruncher mode `19-ZN2 ~ Kagari`.
- `Ryzen7000`: minimum CO `-50`, y-cruncher mode `22-ZN4 ~ Kizuna`.
- `Ryzen8000`: minimum CO `-50`, y-cruncher mode `22-ZN4 ~ Kizuna`.
- `Ryzen9000`: minimum CO `-50`, y-cruncher mode `24-ZN5 ~ Komari`.

Use `Get-CoreCyclerRyzenGenerationProfile` to inspect a profile. When a phase uses `-RyzenGeneration`, generated configs include profile comments and numeric CO values below the profile minimum are rejected.

## Safety Defaults

- `lookForWheaErrors = 1`
- `treatWheaWarningAsError = 1`
- `maxValue = 0`
- Positive CO values are rejected unless `-AllowPositiveCurveOptimizer` is passed explicitly.
- Coarse and fine isolated discovery default to `setVoltageOnlyForTestedCore = 1` and `voltageValueForNotTestedCores = 0`.
- Generated configs include a reminder that SMU-applied CO values are temporary unless persisted elsewhere.

## Using Generated Configs

Generated INI text is not loaded automatically. To run a generated config with CoreCycler, write it to a reviewed file, then either:

- Set `useConfigFile` in `config.ini` to that file path, relative to the repository root, such as `configs\generated.coarse-discovery.ini`.
- Use `Run Multiconfig CoreCycler.bat` with numbered `multiconfig-*.ini` files.

Always review generated configs before use, especially any `AutomaticTestMode`, crash-resume, `startValues`, or positive CO settings.

## Combined-Map Validation

`New-CoreCyclerCombinedMapValidationPhase` consumes either a raw candidate map or the object returned by `Get-CoreCyclerCandidateCurveOptimizerMap`.

The helper emits a `CombinedMapValidation` phase with:

- `startValues` set to the full candidate daily map.
- `setVoltageOnlyForTestedCore = 0`, so generated settings describe whole-map validation instead of isolated-core discovery.
- `enableAutomaticAdjustment = 0`.
- `enableResumeAfterUnexpectedExit = 0`.
- `maxValue = 0`.

The current CoreCycler runtime applies `startValues` only when Automatic Test Mode is enabled. Because this helper intentionally keeps automatic adjustment disabled, generated combined-map validation configs include the candidate map as reviewable intent and assume the candidate map is already active, or that a future guided workflow applies it through a separate explicit step before validation.

```powershell
$summary = ConvertFrom-CoreCyclerSummaryText -Text (Get-Content .\tests\fixtures\final-summary-adjusted-clean.log -Raw)
$recommendation = Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summary -SafetyMargin 2

$phase = New-CoreCyclerCombinedMapValidationPhase `
    -Name 'combined-map-validation' `
    -CandidateMap $recommendation `
    -RyzenGeneration Ryzen7000 `
    -ExpectedCoreCount 4

ConvertTo-CoreCyclerIni -Phase $phase
```

## Transition/CorePairs Validation

`New-CoreCyclerTransitionValidationPhase` consumes either a raw candidate map or the object returned by `Get-CoreCyclerCandidateCurveOptimizerMap`.

The helper emits a `TransitionValidation` phase with:

- `coreTestOrder = CorePairs`.
- `suspendPeriodically = 1`.
- `startValues` set to the full candidate daily map.
- `setVoltageOnlyForTestedCore = 0`.
- `enableAutomaticAdjustment = 0`.
- `enableResumeAfterUnexpectedExit = 0`.
- `maxValue = 0`.

As with combined-map validation, current CoreCycler does not apply `startValues` while automatic adjustment is disabled. Generated transition validation configs record the candidate map and scheduler-transition settings, but assume the candidate map is already active before the run.

## Example

```powershell
Import-Module .\helpers\CoreCyclerPhaseConfig.psm1 -Force

$phase = New-CoreCyclerPhase -Name 'coarse-discovery' -Type CoarseIsolatedDiscovery -RyzenGeneration Ryzen7000 -Sections @{
    General = @{
        runtimePerCore = '6m'
    }
    AutomaticTestMode = @{
        startValues = 'CurrentValues'
        incrementBy = 3
    }
}

$ini = ConvertTo-CoreCyclerIni -Phase $phase
$ini

Export-CoreCyclerPhaseConfig -Phase $phase -OutputPath .\configs\generated.coarse-discovery.ini
```

## Testing

Run the local dependency-free test harness:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
```

These tests cover phase ordering, WHEA defaults, `maxValue = 0`, positive CO guardrails, Ryzen generation profile bounds, unstable-summary rejection, combined-map validation generation, transition/CorePairs validation generation, and full generated-INI fixtures.
