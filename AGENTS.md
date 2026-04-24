# AGENTS.md

## Project Purpose

CoreCycler is a Windows PowerShell tool for per-core CPU stability testing. It launches supported stress programs, pins their worker process or threads to selected physical cores, watches logs and Windows Event Log WHEA entries, and can optionally adjust Curve Optimizer or voltage offset values after instability.

This fork is being prepared for a staged, safer, more automated Ryzen Curve Optimizer tuning workflow. The goal is to guide discovery and validation without changing CoreCycler's conservative defaults or replacing its existing manual/config-driven workflow.

## Agent Workflow

- Inspect before editing. Start with `git status --short`, top-level files, relevant configs, and the functions in `script-corecycler.ps1`.
- Plan before large changes. Prefer small, reviewable diffs over broad rewrites.
- Preserve upstream behavior unless the task explicitly asks for behavior changes.
- Keep user-visible tuning behavior conservative and explicit.
- Add tests for logic changes. If the code remains documentation-only, use lightweight validation and document that no runtime tests were needed.
- Document assumptions in code comments or docs when hardware behavior, Ryzen generation behavior, or safety policy is inferred.
- Avoid reformatting large unrelated sections of `script-corecycler.ps1`; it is a large monolithic script and whitespace churn makes review harder.
- Do not rename major files or reorganize directories unless a task has a strong reason and preserves upstream compatibility.

## Safety Rules

- Never auto-increase instability by making Curve Optimizer values more negative during an automatic recovery step.
- Automatic recovery may only make CO less aggressive, meaning numeric values move upward toward the configured maximum.
- Never allow positive CO by default. The default maximum for automated Ryzen CO adjustment must remain `0`.
- Any positive CO path must require explicit user opt-in, clear warnings, and tests around the guardrail.
- Treat WHEA warnings and errors as instability signals during tuning. WHEA Event ID 19 is not harmless for tuning purposes.
- Do not claim isolated per-core tests prove final daily stability.
- Warn that SMU-applied values are temporary unless later persisted in BIOS or applied by explicit startup tooling.
- Keep crash-resume and Scheduled Task behavior explicit and documented.
- Avoid changes that could silently create boot loops, repeated crash loops, or unattended repeated reboots.
- Prefer failing closed over guessing when parsing CO values, WHEA core IDs, crash-resume state, or generated phase configs.

## Tuning Model

- Baseline sanity: test at neutral CO to catch non-CO instability before tuning.
- Sentinel pass: test known weak, preferred, or favored cores early so an obviously bad starting map fails quickly.
- Coarse isolated discovery: test one core at a time with other cores neutral or safer, using larger upward adjustments toward stability.
- Fine isolated discovery: retest near the discovered edge with smaller upward adjustments, usually one CO point at a time.
- Safety margin: back off from the isolated edge before treating a map as a daily candidate.
- Combined-map validation: test with all candidate CO values active together, because interactions can fail even when isolated tests pass.
- Transition validation: exercise scheduler transitions and core-to-core switches, including `CorePairs` and suspend/resume style load changes.
- Alternate workload validation: validate with y-cruncher, Prime95 modes other than the discovery mode, Linpack, AIDA64, or other supported tools.
- Real-world soak: run ordinary workloads, games, idle/resume, sleep/wake, and long background use before trusting daily settings.
- BIOS finalization: only after validation, export or summarize the final map so the user can apply it deliberately in BIOS or startup tooling.

Keep discovery and validation separate. An edge map found by isolated testing is not a final map. A candidate daily map includes margin. A validated final map has passed combined, transition, alternate workload, and real-world checks.

## Coding Standards

- The runtime is Windows PowerShell 5.1. `script-corecycler.ps1` explicitly rejects PowerShell 6+ because required Windows cmdlets are missing.
- The main launcher is `Run CoreCycler.bat`; multiconfig runs use `Run Multiconfig CoreCycler.bat`.
- Configuration is INI-like text parsed by `Import-Settings` and merged in `Get-Settings`.
- Existing script style uses global variables, `$Script:` assignments for cross-function state, hashtables, arrays, and `Verb-Noun` PowerShell function names.
- Existing logging flows through `Write-Text`, `Write-ColorText`, `Write-VerboseText`, `Write-DebugText`, `Write-LogEntry`, and `Write-AppEventLog`.
- Automatic adjustment is centered around `Initialize-AutomaticTestMode`, `Get-CurveOptimizerValues`, `Set-CurveOptimizerValues`, `Set-NewVoltageValues`, and `Test-AutomaticTestModeIncrease`.
- Stress orchestration is centered around `Initialize-StressTestProgram`, `Start-StressTestProgram`, `Close-StressTestProgram`, `Set-StressTestProgramAffinities`, `Test-StressTestProgrammIsRunning`, and `Resolve-StressTestProgrammIsRunningError`.
- WHEA handling is centered around `Get-LastWheaError`, `Compare-WheaErrorEntries`, `Convert-WheaMessageToApicId`, and `Convert-WheaMessageToCoreId`.
- Final summaries are generated by `Show-FinalSummary`; error detail is collected through `Add-ToErrorCollection`.
- Offline phase config generation is in `helpers/CoreCyclerPhaseConfig.psm1`. It must remain side-effect-free unless a future task explicitly adds guided execution.
- Offline final summary parsing is also in `helpers/CoreCyclerPhaseConfig.psm1`; keep parser fixtures small, synthetic, and independent of stress tools.
- Safety-margin recommendation logic in `helpers/CoreCyclerPhaseConfig.psm1` must only move CO values upward toward safer values, must not emit positive CO without explicit opt-in, and must reject summaries with stress errors or WHEA by default.
- Combined-map validation phase generation in `helpers/CoreCyclerPhaseConfig.psm1` must keep `enableAutomaticAdjustment = 0`, `setVoltageOnlyForTestedCore = 0`, `maxValue = 0`, and positive CO blocked unless explicitly opted in.
- Transition/CorePairs validation phase generation in `helpers/CoreCyclerPhaseConfig.psm1` must keep `coreTestOrder = CorePairs`, `suspendPeriodically = 1`, `enableAutomaticAdjustment = 0`, `setVoltageOnlyForTestedCore = 0`, `maxValue = 0`, and positive CO blocked unless explicitly opted in.
- Ryzen generation profiles in `helpers/CoreCyclerPhaseConfig.psm1` are opt-in defaults, not hidden hardware assumptions. Keep default generated CO maximum at `0`.
- Keep new helpers pure and side-effect-free where practical, especially for phase schema validation, config generation, log parsing, and guardrail checks.

## Config Changes

- Do not surprise existing CoreCycler users by changing defaults in `configs/default.config.ini`.
- Prefer new example configs or generated configs over changing existing defaults.
- Keep generated phase configs explicit about temporary SMU application, WHEA handling, crash-resume behavior, and positive CO policy.
- Combined-map and transition validation configs that include `startValues` are offline artifacts. Current CoreCycler applies `startValues` only through Automatic Test Mode, so these configs assume the candidate map is already active unless a future explicit apply workflow is added.
- Any new phase schema should validate unknown fields, unsupported Ryzen generation defaults, invalid core IDs, malformed CO maps, and values beyond the configured CO floor/ceiling.
- Future config generation should preserve current CoreCycler setting names where possible so generated files remain understandable to upstream users.

## Logging And Guardrails

- Log both starting and current CO maps when automation changes values.
- Preserve enough information to reconstruct which phase, core, stress tool, FFT/test mode, WHEA event, and CO value produced each decision.
- Treat WHEA as a first-class error source in automated tuning summaries, even when APIC-to-core mapping is uncertain.
- Make crash-resume state visible in logs and summaries. Never hide the existence of the `.automode` file or Scheduled Task.
- Positive CO, crash-resume, startup task creation, and SMU-applied temporary values must have clear warnings at the point of use.

## Testing Expectations

- This fork now has a lightweight local PowerShell test harness for offline helper logic.
- For documentation-only changes, run `git diff --check` and inspect the diff.
- For the offline phase config generator, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
```

- For PowerShell edits, at minimum run a parser check without executing the script:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\script-corecycler.ps1), [ref]$tokens, [ref]$errors) | Out-Null
$errors | Format-List
```

- For future pure helpers, prefer a small Pester test scaffold or another lightweight local-only test runner. Do not add network-dependent tests.
- Tests should cover phase ordering, generated config output, CO guardrails, WHEA-aware decisions, summary parsing, and crash-resume safety checks.
