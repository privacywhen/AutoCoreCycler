# Module: Configuration profiles

## Purpose

`configs/` holds INI profiles for stress programs and legacy Automatic Test Mode. The main script imports and validates settings; the default profile documents each setting.

| File | Purpose |
|---|---|
| [`default.config.ini`](../../../configs/default.config.ini) | General configuration reference. |
| [`Ryzen.AutomaticTestMode.Start.ini`](../../../configs/Ryzen.AutomaticTestMode.Start.ini) | Existing Ryzen ATM starter profile. |
| [`Intel.AutomaticTestMode.yCruncher.ini`](../../../configs/Intel.AutomaticTestMode.yCruncher.ini) | Existing Intel ATM profile. |
| [`quick-initial-test.yCruncher.config.ini`](../../../configs/quick-initial-test.yCruncher.config.ini) | Short y-cruncher profile. |
| [`long-final-test.Prime95.config.ini`](../../../configs/long-final-test.Prime95.config.ini) | Longer Prime95 profile. |

## Legacy profiles

The Ryzen starter uses `enableAutomaticAdjustment`, `startValues`, `maxValue`, `incrementBy`, `passesToConfirmCoreValue`, `repeatCoreUntilConfirmed`, `setVoltageOnlyForTestedCore`, and automatic resume. Those configure legacy ATM, not the descending discovery policy.

## Phase 3 stage configs

`script-corecycler.ps1` accepts an optional explicit `-ConfigPath` while preserving no-argument default selection of the repository `config.ini`. An explicit stage config must already exist, must not be the root `config.ini`, and is not repaired or replaced by legacy config-recovery logic. The child-launch plan passes it as a separate `-ConfigPath` argument and binds its exact bytes through a SHA-256 fingerprint.

The discovery design prefers `setVoltageOnlyForTestedCore = 1` and `applyConfirmedValuesForNotTestedCores = 0` for active-core isolation. Configuration alone is not proof of effective application or stability evidence.
