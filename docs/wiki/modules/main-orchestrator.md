# Module: Main orchestrator

## Purpose

[`script-corecycler.ps1`](../../../script-corecycler.ps1) is the application implementation. This large PowerShell script centralizes configuration, logging, dependency checks, CPU/core discovery, stress-program control, affinity, legacy automatic adjustment, persistence, WHEA observation, Event Log integration, and cleanup.

## Current responsibilities

- Resolve the default repository `config.ini` or an optional explicit `-ConfigPath` before settings are read.
- Protect explicit stage-config inputs from falling back to or repairing the legacy root config path; preserve legacy repair behavior for the default path.
- Determine processor, physical-core, logical-CPU, APIC, SMT, and processor-group relationships.
- Initialize/control the selected stress program and assign affinity.
- Initialize legacy Automatic Test Mode and coordinate its state, results, and resume behavior.
- Optionally import/export discovery state under `discoveryStates` through the Phase 2 helper contract without changing legacy documents when discovery is unused.

## Important functions

| Function | Role |
|---|---|
| `Resolve-CoreCyclerConfigInput` | Selects default or explicit config input and rejects invalid explicit paths. |
| `Import-Settings` / `Get-Settings` | Parse and validate configuration. |
| `Initialize-AutomaticTestMode` | Prepare existing ATM values, state, persistence, and resume. |
| `Save-AutoModeState` / `Get-AutoModeFileContent` | Persist and recover legacy state plus optional validated discovery snapshots. |
| `Initialize-StressTestProgram` / `Start-StressTestProgram` / `Close-StressTestProgram` | Generic adapter lifecycle. |
| `Set-StressTestProgramAffinities` | Assign stress threads to selected physical-core CPUs. |
| `Get-ProcessorCoresInformation` | Build CPU/core/APIC lookup tables using APICID. |

## Discovery boundary

The main script currently provides config-input and optional persistence integration only. It does not import the Phase 3 stage, suite, or child-launch helpers; there is no production discovery scheduler or runtime child coordinator yet. Legacy ATM direction and evidence semantics remain uphill-only and separate from descending discovery.
