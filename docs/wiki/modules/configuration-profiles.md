# Module: Configuration profiles

## Purpose

`configs/` holds INI profiles for stress programs and Automatic Test Mode. The main script imports and validates settings; the default profile documents each setting.

| File | Purpose |
|---|---|
| [`default.config.ini`](../../../configs/default.config.ini) | General configuration reference. |
| [`Ryzen.AutomaticTestMode.Start.ini`](../../../configs/Ryzen.AutomaticTestMode.Start.ini) | Existing Ryzen ATM starter profile. |
| [`Intel.AutomaticTestMode.yCruncher.ini`](../../../configs/Intel.AutomaticTestMode.yCruncher.ini) | Existing Intel ATM profile. |
| [`quick-initial-test.yCruncher.config.ini`](../../../configs/quick-initial-test.yCruncher.config.ini) | Short y-cruncher profile. |
| [`long-final-test.Prime95.config.ini`](../../../configs/long-final-test.Prime95.config.ini) | Longer Prime95 profile. |

The Ryzen starter uses `enableAutomaticAdjustment`, `startValues`, `maxValue`, `incrementBy`, `passesToConfirmCoreValue`, `repeatCoreUntilConfirmed`, `setVoltageOnlyForTestedCore`, and automatic resume. Those configure legacy ATM, not the proposed full discovery suite.

The discovery design prefers `setVoltageOnlyForTestedCore = 1` and `applyConfirmedValuesForNotTestedCores = 0` for active-core isolation. Configuration alone is not proof of effective application or stability evidence.
