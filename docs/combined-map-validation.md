# Combined-Map Validation Generation

`New-CoreCyclerCombinedMapValidationPhase` turns a candidate daily Curve Optimizer map into an offline CoreCycler phase definition for combined-map validation.

This helper does not run CoreCycler, apply SMU values, create Scheduled Tasks, or write BIOS settings.

## Inputs

The `-CandidateMap` parameter accepts either:

- A raw map, such as `@(-18, -15, -13, -26)`.
- A delimited string, such as `'-18, -15, -13, -26'`.
- The recommendation object returned by `Get-CoreCyclerCandidateCurveOptimizerMap`.

Use `-ExpectedCoreCount` when the intended physical core count is known. The helper rejects maps with a different number of entries.

## Generated Policy

The generated phase forces the settings that distinguish validation from isolated discovery:

- `enableAutomaticAdjustment = 0`
- `setVoltageOnlyForTestedCore = 0`
- `voltageValueForNotTestedCores = 0`
- `enableResumeAfterUnexpectedExit = 0`
- `maxValue = 0`

Positive CO values are rejected unless `-AllowPositiveCurveOptimizer` is passed to the phase helper, and `ConvertTo-CoreCyclerIni` still requires `-AllowPositiveCurveOptimizer` when rendering the INI.

Generated INI output includes `# CandidateMap = ...` and `# MapApplication = ...` comments so the file remains explicit about whether the candidate map is only recorded or actually active.

## Runtime Assumption

Current CoreCycler applies `startValues` only when Automatic Test Mode is enabled. This helper intentionally keeps Automatic Test Mode adjustment disabled, so a generated combined-map validation config records the candidate map and whole-map validation settings but does not apply the candidate map by itself.

For now, use the generated config only after the candidate map is already active through BIOS, Ryzen Master, or another explicit manual process. A future guided execution task can add a separate opt-in apply step.

To make CoreCycler load a generated config, either set `useConfigFile` in `config.ini` to the generated file path or use the multiconfig runner with numbered `multiconfig-*.ini` files.
