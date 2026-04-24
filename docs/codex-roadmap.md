# Codex Roadmap

This roadmap breaks the staged tuning goal into small future tasks that are safe for separate Codex sessions. Each task should preserve existing CoreCycler behavior unless explicitly scoped otherwise.

## 1. Add A Phase Schema Draft

Status: initial offline helper added in `helpers/CoreCyclerPhaseConfig.psm1`.

Scope:
- Define a declarative phase model in documentation first, then a small data structure if needed.
- Include phase name, stress tool settings, core order, CO map source, WHEA policy, automatic adjustment policy, resume policy, and expected outputs.

Validation:
- Add tests or examples for required fields, unknown fields, invalid phase order, and invalid CO bounds.

## 2. Add A Phase Config Generator

Status: initial offline CoreCycler INI generator added in `helpers/CoreCyclerPhaseConfig.psm1`.

Scope:
- Generate regular CoreCycler INI configs from a phase definition.
- Start as an offline helper that writes files into a user-selected output directory.
- Do not execute CoreCycler yet.

Validation:
- Snapshot tests for generated INI content.
- Guardrail tests for `maxValue = 0`, `treatWheaWarningAsError = 1`, and no accidental positive CO.

## 3. Add Ryzen Generation Profile Defaults

Status: initial opt-in profiles added for Ryzen 5000, 7000, 8000, and 9000.

Scope:
- Add conservative defaults for Ryzen 5000, 7000, 8000, and 9000 families.
- Keep these as suggested profiles, not automatic hardware assumptions that cannot be overridden.

Validation:
- Tests for generation detection inputs and fallback behavior.
- Tests that defaults never opt into positive CO.

## 4. Add Known Weak/Favored Core Sentinel Mode

Scope:
- Let users specify sentinel cores or import them from a simple list.
- Generate a custom `coreTestOrder` that can repeat sentinel cores.

Validation:
- Tests for zero-based core numbering, duplicates, ignored cores, and out-of-range core IDs.

## 5. Add Coarse-To-Fine Reseeding Logic

Scope:
- Read a coarse phase result and seed a fine phase from it.
- Keep edge maps separate from candidate daily maps.

Validation:
- Tests for map length, per-core reseeding, upward-only recovery, and safety margin application.

## 6. Add Summary Parser For CO Values And Errors

Status: initial offline parser and fixtures added for final CO maps, WHEA counts, and per-core errors.

Scope:
- Parse CoreCycler logs or final summary text into structured data.
- Extract starting/current CO maps, cores with errors, WHEA counts, stress tool, mode, phase name, and timestamps.

Validation:
- Fixture-based parser tests using small synthetic log excerpts.
- Tests for missing sections and partial logs after crash.

## 7. Add WHEA-Aware Decision Logic

Scope:
- Make WHEA policy explicit in phase decisions.
- Treat WHEA warnings/errors as instability signals during tuning.
- Preserve uncertainty when APIC-to-core mapping does not match the currently tested core.

Validation:
- Unit tests for WHEA event levels, Event IDs 18 and 19, APIC mapping success, APIC mapping failure, and non-matching core warnings.

## 8. Add Combined-Map Validation Mode

Status: initial offline phase generation added with automatic adjustment disabled.

Scope:
- Generate or run validation phases with all candidate CO values active.
- Keep automatic adjustment disabled by default, or strictly upward toward `0` when explicitly enabled.

Validation:
- Tests that `setVoltageOnlyForTestedCore = 0` is emitted for combined validation.
- Tests that isolated edge maps are not labeled final.

## 9. Add Transition/CorePairs Validation Mode

Status: initial offline phase generation added with automatic adjustment disabled.

Scope:
- Generate transition validation configs using `coreTestOrder = CorePairs`, suspend/resume settings, and candidate maps.
- Keep output warnings clear that this tests scheduler/load transitions, not every real-world scenario.

Validation:
- Tests for generated `CorePairs` settings, forced automatic-adjustment-off guardrails, positive CO opt-in, and expected core counts.
- Future tests should cover ignored-core interactions if the generator starts accepting explicit ignored-core lists.

## 10. Add Safety-Margin Recommendation Logic

Status: initial offline recommendation helper added with global margin support.

Scope:
- Recommend a less aggressive candidate daily map from an edge map.
- Support a global margin and optional per-core margins.

Validation:
- Tests for negative, zero, and near-zero values.
- Tests that margins never make a value more negative.
- Tests that positive output requires explicit opt-in.

## 11. Add BIOS/Startup Export Guidance

Scope:
- Export a final report with edge map, candidate daily map, validated final map, phase history, and warnings.
- Include zero-based CoreCycler numbering and BIOS/Ryzen Master numbering caveats.
- Do not automate BIOS writes.

Validation:
- Snapshot tests for report text.
- Tests that temporary SMU warning is present.

## 12. Add Ryzen 5000+ Docs And Examples

Scope:
- Add concise examples for Ryzen 5000, 7000, 8000, and 9000 staged workflows.
- Include Prime95 Huge/SSE discovery, y-cruncher validation, WHEA handling, and crash-resume cautions.

Validation:
- Review generated examples against current config names.
- Keep examples opt-in and out of `default.config.ini`.

## 13. Add Lightweight Test Harness

Scope:
- Introduce Pester or a small PowerShell-local test runner only once pure helper logic exists.
- Keep tests offline and independent of bundled stress programs.

Validation:
- CI or local command that parses PowerShell, runs pure tests, and does not require admin rights, SMU access, or network.

## 14. Add Optional Guided Execution

Scope:
- After generation and parsing are reliable, add an opt-in runner that executes phases one at a time.
- Require confirmation for SMU writes, crash-resume, positive CO, and startup tasks.
- Make pause/resume state visible and recoverable.

Validation:
- Dry-run tests for command construction.
- Integration checklist for manual hardware testing.
- Tests that dangerous options require explicit user confirmation.

## Recommended Next Task

Add alternate workload validation phase generation that consumes candidate daily maps and emits y-cruncher validation configs with automatic adjustment disabled by default.
